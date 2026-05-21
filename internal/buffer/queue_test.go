package buffer

import (
	"context"
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type captureWriter struct {
	batches [][]readings.SensorReading
}

func (w *captureWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	copied := append([]readings.SensorReading(nil), batch...)
	w.batches = append(w.batches, copied)
	return nil
}

type captureMetrics struct {
	metrics []IngestionMetric
}

func (m *captureMetrics) RecordIngestionMetrics(_ context.Context, metric IngestionMetric) error {
	m.metrics = append(m.metrics, metric)
	return nil
}

func TestQueueAcceptsUpToCapacityAndDropsWhenFull(t *testing.T) {
	writer := &captureWriter{}
	queue, err := NewQueue(writer, nil, Config{Capacity: 2, BatchSize: 10, FlushInterval: time.Second})
	if err != nil {
		t.Fatalf("NewQueue() error = %v", err)
	}

	result := queue.PublishBatch([]readings.SensorReading{reading(), reading(), reading()})
	if result.Accepted != 2 || result.Dropped != 1 {
		t.Fatalf("PublishBatch() = %+v, want accepted=2 dropped=1", result)
	}

	stats := queue.Stats()
	if stats.Queued != 2 || stats.FillPct != 100 || stats.Dropped != 1 {
		t.Fatalf("unexpected stats: %+v", stats)
	}
}

func TestQueueFlushesBatchesAndRecordsMetrics(t *testing.T) {
	writer := &captureWriter{}
	metrics := &captureMetrics{}
	queue, err := NewQueue(writer, metrics, Config{Capacity: 10, BatchSize: 2, FlushInterval: time.Hour})
	if err != nil {
		t.Fatalf("NewQueue() error = %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	queue.Start(ctx)

	result := queue.PublishBatch([]readings.SensorReading{reading(), reading(), reading()})
	if result.Accepted != 3 || result.Dropped != 0 {
		t.Fatalf("PublishBatch() = %+v", result)
	}

	closeCtx, closeCancel := context.WithTimeout(context.Background(), time.Second)
	defer closeCancel()
	if err := queue.Close(closeCtx); err != nil {
		t.Fatalf("Close() error = %v", err)
	}

	if len(writer.batches) != 2 {
		t.Fatalf("len(writer.batches) = %d, want 2", len(writer.batches))
	}
	if got := len(writer.batches[0]); got != 2 {
		t.Fatalf("first batch size = %d, want 2", got)
	}
	if got := len(writer.batches[1]); got != 1 {
		t.Fatalf("second batch size = %d, want 1", got)
	}

	stats := queue.Stats()
	if stats.Flushed != 3 {
		t.Fatalf("flushed = %d, want 3", stats.Flushed)
	}
	if len(metrics.metrics) == 0 {
		t.Fatal("expected ingestion metrics to be recorded")
	}
}

func TestQueueCloseDropsLatePublishes(t *testing.T) {
	writer := &captureWriter{}
	queue, err := NewQueue(writer, nil, Config{Capacity: 1, BatchSize: 1, FlushInterval: time.Hour})
	if err != nil {
		t.Fatalf("NewQueue() error = %v", err)
	}
	queue.Start(context.Background())

	closeCtx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := queue.Close(closeCtx); err != nil {
		t.Fatalf("Close() error = %v", err)
	}

	result := queue.PublishBatch([]readings.SensorReading{reading()})
	if result.Accepted != 0 || result.Dropped != 1 {
		t.Fatalf("PublishBatch() after close = %+v", result)
	}
}

func reading() readings.SensorReading {
	now := time.Date(2026, 5, 21, 12, 0, 0, 0, time.UTC)
	return readings.SensorReading{
		Time:          now,
		SensorID:      "TEST-001",
		Metric:        "PM2.5",
		Value:         10,
		Unit:          "ug/m3",
		Source:        readings.SourceSimulator,
		Latitude:      41.88,
		Longitude:     -87.63,
		QualityFlag:   readings.QualityValid,
		IngestedAt:    now,
		SchemaVersion: readings.SchemaVersion,
	}
}
