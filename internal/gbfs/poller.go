package gbfs

import (
	"context"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type ReadingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type PollConfig struct {
	StationLimit int
}

type PollStats struct {
	Stations  int
	Published int
	Skipped   int
}

type Poller struct {
	client *Client
	writer ReadingWriter
	logger *log.Logger
	config PollConfig
}

func NewPoller(client *Client, writer ReadingWriter, config PollConfig, logger *log.Logger) (*Poller, error) {
	if client == nil {
		return nil, fmt.Errorf("GBFS client is required")
	}
	if writer == nil {
		return nil, fmt.Errorf("reading writer is required")
	}
	if config.StationLimit < 0 {
		return nil, fmt.Errorf("GBFS station limit cannot be negative")
	}
	if logger == nil {
		logger = log.New(io.Discard, "", 0)
	}
	return &Poller{client: client, writer: writer, logger: logger, config: config}, nil
}

func (p *Poller) PollOnce(ctx context.Context) (PollStats, error) {
	info, status, err := p.client.FetchStations(ctx)
	if err != nil {
		return PollStats{}, err
	}

	now := time.Now().UTC()
	batch, skipped := NormalizeStations(info, status, p.config.StationLimit, now)
	valid := batch[:0]
	for _, reading := range batch {
		if err := readings.Validate(reading, reading.Time); err != nil {
			skipped = append(skipped, fmt.Sprintf("invalid GBFS reading %s: %v", reading.DedupKey(), err))
			continue
		}
		valid = append(valid, reading)
	}
	for _, reason := range skipped {
		p.logger.Printf("skip GBFS reading: %s", reason)
	}

	if err := p.writer.InsertReadings(ctx, valid); err != nil {
		return PollStats{}, fmt.Errorf("publish GBFS readings: %w", err)
	}
	return PollStats{Stations: len(status.Data.Stations), Published: len(valid), Skipped: len(skipped)}, nil
}
