package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/openaq"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/timescale"
)

const defaultTimescaleDSN = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"

func main() {
	logger := log.New(os.Stdout, "openaq-poller ", log.LstdFlags|log.LUTC)

	cfg, err := loadConfig()
	if err != nil {
		logger.Fatalf("load config: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	client, err := openaq.NewClient(cfg.baseURL, cfg.apiKey, nil)
	if err != nil {
		logger.Fatalf("create OpenAQ client: %v", err)
	}

	writer, err := timescale.Connect(ctx, cfg.timescaleDSN)
	if err != nil {
		logger.Fatalf("connect to TimescaleDB: %v", err)
	}
	defer writer.Close()

	poller, err := openaq.NewPoller(client, writer, openaq.PollConfig{
		Coordinates:   cfg.coordinates,
		RadiusMeters:  cfg.radiusMeters,
		LocationLimit: cfg.locationLimit,
	}, logger)
	if err != nil {
		logger.Fatalf("create poller: %v", err)
	}

	logger.Printf(
		"starting continuous OpenAQ polling coordinates=%s radius_meters=%d location_limit=%d interval=%s",
		cfg.coordinates,
		cfg.radiusMeters,
		cfg.locationLimit,
		cfg.pollInterval,
	)

	runPoll(ctx, poller, logger)
	ticker := time.NewTicker(cfg.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			logger.Print("stopping OpenAQ poller")
			return
		case <-ticker.C:
			runPoll(ctx, poller, logger)
		}
	}
}

type config struct {
	apiKey        string
	baseURL       string
	coordinates   string
	radiusMeters  int
	locationLimit int
	pollInterval  time.Duration
	timescaleDSN  string
}

func loadConfig() (config, error) {
	pollSeconds, err := envInt("OPENAQ_POLL_INTERVAL_SECONDS", 60)
	if err != nil {
		return config{}, err
	}
	if pollSeconds <= 0 {
		return config{}, fmt.Errorf("OPENAQ_POLL_INTERVAL_SECONDS must be positive")
	}

	radiusMeters, err := envInt("OPENAQ_RADIUS_METERS", 25000)
	if err != nil {
		return config{}, err
	}
	if radiusMeters <= 0 || radiusMeters > 25000 {
		return config{}, fmt.Errorf("OPENAQ_RADIUS_METERS must be between 1 and 25000")
	}

	locationLimit, err := envInt("OPENAQ_LOCATION_LIMIT", 5)
	if err != nil {
		return config{}, err
	}
	if locationLimit <= 0 {
		return config{}, fmt.Errorf("OPENAQ_LOCATION_LIMIT must be positive")
	}

	cfg := config{
		apiKey:        os.Getenv("OPENAQ_API_KEY"),
		baseURL:       envOrDefault("OPENAQ_BASE_URL", openaq.DefaultBaseURL),
		coordinates:   envOrDefault("OPENAQ_COORDINATES", "41.8781,-87.6298"),
		radiusMeters:  radiusMeters,
		locationLimit: locationLimit,
		pollInterval:  time.Duration(pollSeconds) * time.Second,
		timescaleDSN:  envOrDefault("TIMESCALE_DSN", defaultTimescaleDSN),
	}
	if cfg.apiKey == "" {
		return config{}, fmt.Errorf("OPENAQ_API_KEY is required")
	}
	return cfg, nil
}

func runPoll(ctx context.Context, poller *openaq.Poller, logger *log.Logger) {
	stats, err := poller.PollOnce(ctx)
	if err != nil {
		logger.Printf("poll failed: %v", err)
		return
	}
	logger.Printf(
		"poll complete locations=%d measurements=%d inserted=%d skipped=%d",
		stats.Locations,
		stats.Measurements,
		stats.Inserted,
		stats.Skipped,
	)
}

func envOrDefault(name, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	return value
}

func envInt(name string, fallback int) (int, error) {
	value := os.Getenv(name)
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be an integer: %w", name, err)
	}
	return parsed, nil
}
