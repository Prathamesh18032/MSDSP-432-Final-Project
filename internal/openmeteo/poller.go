package openmeteo

import (
	"context"
	"fmt"
	"io"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type ReadingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type PollConfig struct {
	Coordinates string
}

type PollStats struct {
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
		return nil, fmt.Errorf("Open-Meteo client is required")
	}
	if writer == nil {
		return nil, fmt.Errorf("reading writer is required")
	}
	if strings.TrimSpace(config.Coordinates) == "" {
		return nil, fmt.Errorf("Open-Meteo coordinates are required")
	}
	if logger == nil {
		logger = log.New(io.Discard, "", 0)
	}
	return &Poller{client: client, writer: writer, logger: logger, config: config}, nil
}

func (p *Poller) PollOnce(ctx context.Context) (PollStats, error) {
	latitude, longitude, err := ParseCoordinates(p.config.Coordinates)
	if err != nil {
		return PollStats{}, err
	}

	response, err := p.client.Current(ctx, latitude, longitude)
	if err != nil {
		return PollStats{}, fmt.Errorf("fetch Open-Meteo current weather: %w", err)
	}

	now := time.Now().UTC()
	sensorID := fmt.Sprintf("OPENMETEO-%.4f-%.4f", latitude, longitude)
	batch, skipped := NormalizeCurrent(response, sensorID, now)

	valid := batch[:0]
	for _, reading := range batch {
		if err := readings.Validate(reading, reading.Time); err != nil {
			skipped = append(skipped, fmt.Sprintf("invalid Open-Meteo reading %s: %v", reading.DedupKey(), err))
			continue
		}
		valid = append(valid, reading)
	}
	for _, reason := range skipped {
		p.logger.Printf("skip Open-Meteo reading: %s", reason)
	}

	if err := p.writer.InsertReadings(ctx, valid); err != nil {
		return PollStats{}, fmt.Errorf("publish Open-Meteo readings: %w", err)
	}

	return PollStats{Published: len(valid), Skipped: len(skipped)}, nil
}

func ParseCoordinates(value string) (float64, float64, error) {
	parts := strings.Split(value, ",")
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("coordinates must be in latitude,longitude format")
	}
	latitude, err := parseCoordinate(parts[0], -90, 90, "latitude")
	if err != nil {
		return 0, 0, err
	}
	longitude, err := parseCoordinate(parts[1], -180, 180, "longitude")
	if err != nil {
		return 0, 0, err
	}
	return latitude, longitude, nil
}

func parseCoordinate(value string, minValue, maxValue float64, name string) (float64, error) {
	parsed, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
	if err != nil {
		return 0, fmt.Errorf("%s must be a number: %w", name, err)
	}
	if parsed < minValue || parsed > maxValue {
		return 0, fmt.Errorf("%s must be between %.0f and %.0f", name, minValue, maxValue)
	}
	return parsed, nil
}
