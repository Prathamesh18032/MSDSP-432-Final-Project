package openaq

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
	Coordinates   string
	RadiusMeters  int
	LocationLimit int
}

type PollStats struct {
	Locations    int
	Measurements int
	Published    int
	Skipped      int
}

type Poller struct {
	client *Client
	writer ReadingWriter
	logger *log.Logger
	config PollConfig
}

func NewPoller(client *Client, writer ReadingWriter, config PollConfig, logger *log.Logger) (*Poller, error) {
	if client == nil {
		return nil, fmt.Errorf("OpenAQ client is required")
	}
	if writer == nil {
		return nil, fmt.Errorf("reading writer is required")
	}
	if config.Coordinates == "" {
		return nil, fmt.Errorf("OpenAQ coordinates are required")
	}
	if config.RadiusMeters <= 0 || config.RadiusMeters > 25000 {
		return nil, fmt.Errorf("OpenAQ radius must be between 1 and 25000 meters")
	}
	if config.LocationLimit <= 0 {
		return nil, fmt.Errorf("OpenAQ location limit must be positive")
	}
	if logger == nil {
		logger = log.New(io.Discard, "", 0)
	}

	return &Poller{client: client, writer: writer, logger: logger, config: config}, nil
}

func (p *Poller) PollOnce(ctx context.Context) (PollStats, error) {
	var stats PollStats

	locations, err := p.client.ListLocations(ctx, p.config.Coordinates, p.config.RadiusMeters, p.config.LocationLimit)
	if err != nil {
		return stats, fmt.Errorf("list OpenAQ locations: %w", err)
	}
	stats.Locations = len(locations)

	now := time.Now().UTC()
	batch := make([]readings.SensorReading, 0)

	for _, location := range locations {
		sensors, err := p.client.ListSensors(ctx, location.ID)
		if err != nil {
			return stats, fmt.Errorf("list OpenAQ sensors for location %d: %w", location.ID, err)
		}
		sensorByID := map[int]SensorMeta{}
		for _, sensor := range sensors {
			sensorByID[sensor.ID] = sensor
		}

		latest, err := p.client.LatestByLocation(ctx, location.ID)
		if err != nil {
			return stats, fmt.Errorf("list OpenAQ latest measurements for location %d: %w", location.ID, err)
		}
		stats.Measurements += len(latest)

		for _, measurement := range latest {
			sensor, ok := sensorByID[measurement.SensorsID]
			if !ok {
				stats.Skipped++
				p.logger.Printf("skip OpenAQ measurement for unknown sensor %d", measurement.SensorsID)
				continue
			}

			reading, ok, reason := NormalizeMeasurement(measurement, sensor, now)
			if !ok {
				stats.Skipped++
				p.logger.Printf("skip OpenAQ measurement for sensor %d: %s", measurement.SensorsID, reason)
				continue
			}
			if err := readings.Validate(reading, reading.Time); err != nil {
				stats.Skipped++
				p.logger.Printf("skip invalid OpenAQ reading %s: %v", reading.DedupKey(), err)
				continue
			}
			batch = append(batch, reading)
		}
	}

	if err := p.writer.InsertReadings(ctx, batch); err != nil {
		return stats, fmt.Errorf("publish OpenAQ readings: %w", err)
	}
	stats.Published = len(batch)

	return stats, nil
}
