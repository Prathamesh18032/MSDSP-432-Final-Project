package usgs

import (
	"context"
	"fmt"
	"io"
	"log"
	"strings"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type ReadingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type PollConfig struct {
	SiteIDs        string
	ParameterCodes string
}

type PollStats struct {
	TimeSeries int
	Published  int
	Skipped    int
}

type Poller struct {
	client *Client
	writer ReadingWriter
	logger *log.Logger
	config PollConfig
}

func NewPoller(client *Client, writer ReadingWriter, config PollConfig, logger *log.Logger) (*Poller, error) {
	if client == nil {
		return nil, fmt.Errorf("USGS client is required")
	}
	if writer == nil {
		return nil, fmt.Errorf("reading writer is required")
	}
	if strings.TrimSpace(config.SiteIDs) == "" {
		return nil, fmt.Errorf("USGS site IDs are required")
	}
	if strings.TrimSpace(config.ParameterCodes) == "" {
		return nil, fmt.Errorf("USGS parameter codes are required")
	}
	if logger == nil {
		logger = log.New(io.Discard, "", 0)
	}
	return &Poller{client: client, writer: writer, logger: logger, config: config}, nil
}

func (p *Poller) PollOnce(ctx context.Context) (PollStats, error) {
	response, err := p.client.InstantaneousValues(ctx, p.config.SiteIDs, p.config.ParameterCodes)
	if err != nil {
		return PollStats{}, fmt.Errorf("fetch USGS instantaneous values: %w", err)
	}

	now := time.Now().UTC()
	batch, skipped := NormalizeInstantaneous(response, now)
	valid := batch[:0]
	for _, reading := range batch {
		if err := readings.Validate(reading, reading.Time); err != nil {
			skipped = append(skipped, fmt.Sprintf("invalid USGS reading %s: %v", reading.DedupKey(), err))
			continue
		}
		valid = append(valid, reading)
	}
	for _, reason := range skipped {
		p.logger.Printf("skip USGS reading: %s", reason)
	}

	if err := p.writer.InsertReadings(ctx, valid); err != nil {
		return PollStats{}, fmt.Errorf("publish USGS readings: %w", err)
	}
	return PollStats{TimeSeries: len(response.Value.TimeSeries), Published: len(valid), Skipped: len(skipped)}, nil
}
