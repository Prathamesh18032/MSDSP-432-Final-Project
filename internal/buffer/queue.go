package buffer

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type ReadingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type MetricsWriter interface {
	RecordIngestionMetrics(ctx context.Context, metric IngestionMetric) error
}

type Config struct {
	Capacity      int
	BatchSize     int
	FlushInterval time.Duration
}

type IngestionMetric struct {
	RecordedAt           time.Time
	ReadingsPerSecond    float64
	ChannelFillPct       int16
	PubSubLagMillis      *int
	GCSWriteLatencyMS    *int
	DroppedReadingsTotal int64
}

type PublishResult struct {
	Accepted int
	Dropped  int
}

type Stats struct {
	Queued   int
	Capacity int
	FillPct  int16
	Accepted int64
	Dropped  int64
	Flushed  int64
}

type Queue struct {
	ch      chan readings.SensorReading
	writer  ReadingWriter
	metrics MetricsWriter
	config  Config

	startOnce sync.Once
	closeOnce sync.Once
	closeMu   sync.RWMutex
	done      chan struct{}
	closed    atomic.Bool

	accepted int64
	dropped  int64
	flushed  int64
}

func NewQueue(writer ReadingWriter, metrics MetricsWriter, config Config) (*Queue, error) {
	if writer == nil {
		return nil, fmt.Errorf("reading writer is required")
	}
	if config.Capacity <= 0 {
		return nil, fmt.Errorf("queue capacity must be positive")
	}
	if config.BatchSize <= 0 {
		return nil, fmt.Errorf("queue batch size must be positive")
	}
	if config.FlushInterval <= 0 {
		return nil, fmt.Errorf("queue flush interval must be positive")
	}

	return &Queue{
		ch:      make(chan readings.SensorReading, config.Capacity),
		writer:  writer,
		metrics: metrics,
		config:  config,
		done:    make(chan struct{}),
	}, nil
}

func (q *Queue) Start(ctx context.Context) {
	q.startOnce.Do(func() {
		go q.run(ctx)
	})
}

func (q *Queue) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	q.PublishBatch(batch)
	return nil
}

func (q *Queue) PublishBatch(batch []readings.SensorReading) PublishResult {
	result := PublishResult{}
	for _, reading := range batch {
		q.closeMu.RLock()
		if q.closed.Load() {
			q.closeMu.RUnlock()
			result.Dropped++
			atomic.AddInt64(&q.dropped, 1)
			continue
		}

		select {
		case q.ch <- reading:
			result.Accepted++
			atomic.AddInt64(&q.accepted, 1)
		default:
			result.Dropped++
			atomic.AddInt64(&q.dropped, 1)
		}
		q.closeMu.RUnlock()
	}
	return result
}

func (q *Queue) Close(ctx context.Context) error {
	q.closeOnce.Do(func() {
		q.closeMu.Lock()
		defer q.closeMu.Unlock()
		q.closed.Store(true)
		close(q.ch)
	})

	select {
	case <-q.done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (q *Queue) Stats() Stats {
	capacity := cap(q.ch)
	queued := len(q.ch)
	return Stats{
		Queued:   queued,
		Capacity: capacity,
		FillPct:  fillPct(queued, capacity),
		Accepted: atomic.LoadInt64(&q.accepted),
		Dropped:  atomic.LoadInt64(&q.dropped),
		Flushed:  atomic.LoadInt64(&q.flushed),
	}
}

func (q *Queue) run(ctx context.Context) {
	defer close(q.done)

	ticker := time.NewTicker(q.config.FlushInterval)
	defer ticker.Stop()

	batch := make([]readings.SensorReading, 0, q.config.BatchSize)
	lastMetricsAt := time.Now().UTC()
	lastFlushed := int64(0)

	flush := func() {
		if len(batch) == 0 {
			q.recordMetrics(ctx, lastMetricsAt, &lastFlushed)
			lastMetricsAt = time.Now().UTC()
			return
		}

		if err := q.writer.InsertReadings(ctx, batch); err == nil {
			atomic.AddInt64(&q.flushed, int64(len(batch)))
		}
		batch = batch[:0]
		q.recordMetrics(ctx, lastMetricsAt, &lastFlushed)
		lastMetricsAt = time.Now().UTC()
	}

	for {
		select {
		case reading, ok := <-q.ch:
			if !ok {
				flush()
				return
			}
			batch = append(batch, reading)
			if len(batch) >= q.config.BatchSize {
				flush()
			}
		case <-ticker.C:
			flush()
		case <-ctx.Done():
			for {
				select {
				case reading, ok := <-q.ch:
					if !ok {
						flush()
						return
					}
					batch = append(batch, reading)
					if len(batch) >= q.config.BatchSize {
						flush()
					}
				default:
					flush()
					return
				}
			}
		}
	}
}

func (q *Queue) recordMetrics(ctx context.Context, previous time.Time, lastFlushed *int64) {
	if q.metrics == nil {
		return
	}

	now := time.Now().UTC()
	flushed := atomic.LoadInt64(&q.flushed)
	delta := flushed - *lastFlushed
	*lastFlushed = flushed

	elapsed := now.Sub(previous).Seconds()
	var rps float64
	if elapsed > 0 {
		rps = float64(delta) / elapsed
	}

	stats := q.Stats()
	_ = q.metrics.RecordIngestionMetrics(ctx, IngestionMetric{
		RecordedAt:           now,
		ReadingsPerSecond:    rps,
		ChannelFillPct:       stats.FillPct,
		DroppedReadingsTotal: stats.Dropped,
	})
}

func fillPct(queued, capacity int) int16 {
	if capacity <= 0 {
		return 0
	}
	return int16((queued * 100) / capacity)
}
