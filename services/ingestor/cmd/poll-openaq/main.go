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

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/buffer"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/cloudpubsub"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/openaq"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/timescale"
)

const defaultTimescaleDSN = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"
const (
	sinkLocal  = "local"
	sinkPubSub = "pubsub"
)

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

	sink, err := buildReadingSink(ctx, cfg, logger)
	if err != nil {
		logger.Fatalf("create reading sink: %v", err)
	}
	defer sink.close()

	poller, err := openaq.NewPoller(client, sink.writer, openaq.PollConfig{
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
	logger.Printf("ingestion sink=%s", cfg.ingestionSink)
	logger.Print(sink.description)

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
	ingestionSink string
	queue         buffer.Config
	pubsub        pubsubConfig
}

type pubsubConfig struct {
	projectID string
	topicID   string
}

type readingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type readingSink struct {
	writer      readingWriter
	description string
	close       func()
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

	ingestionSink := envOrDefault("INGESTION_SINK", sinkLocal)
	if ingestionSink != sinkLocal && ingestionSink != sinkPubSub {
		return config{}, fmt.Errorf("INGESTION_SINK must be %q or %q", sinkLocal, sinkPubSub)
	}

	queueConfig, err := loadQueueConfig()
	if err != nil {
		return config{}, err
	}

	cfg := config{
		apiKey:        os.Getenv("OPENAQ_API_KEY"),
		baseURL:       envOrDefault("OPENAQ_BASE_URL", openaq.DefaultBaseURL),
		coordinates:   envOrDefault("OPENAQ_COORDINATES", "41.8781,-87.6298"),
		radiusMeters:  radiusMeters,
		locationLimit: locationLimit,
		pollInterval:  time.Duration(pollSeconds) * time.Second,
		timescaleDSN:  envOrDefault("TIMESCALE_DSN", defaultTimescaleDSN),
		ingestionSink: ingestionSink,
		queue:         queueConfig,
		pubsub: pubsubConfig{
			projectID: os.Getenv("GCP_PROJECT_ID"),
			topicID:   envOrDefault("GCP_PUBSUB_TOPIC", cloudpubsub.DefaultTopicID),
		},
	}
	if cfg.apiKey == "" {
		return config{}, fmt.Errorf("OPENAQ_API_KEY is required")
	}
	return cfg, nil
}

func buildReadingSink(ctx context.Context, cfg config, logger *log.Logger) (*readingSink, error) {
	switch cfg.ingestionSink {
	case sinkLocal:
		writer, err := timescale.Connect(ctx, cfg.timescaleDSN)
		if err != nil {
			return nil, fmt.Errorf("connect to TimescaleDB: %w", err)
		}

		queue, err := buffer.NewQueue(writer, writer, cfg.queue)
		if err != nil {
			writer.Close()
			return nil, fmt.Errorf("create local buffer: %w", err)
		}
		queue.Start(context.Background())

		return &readingSink{
			writer: queue,
			description: fmt.Sprintf(
				"local buffer capacity=%d batch_size=%d flush_interval=%s",
				cfg.queue.Capacity,
				cfg.queue.BatchSize,
				cfg.queue.FlushInterval,
			),
			close: func() {
				closeCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				defer cancel()
				if err := queue.Close(closeCtx); err != nil {
					logger.Printf("flush local buffer: %v", err)
				}
				writer.Close()
			},
		}, nil
	case sinkPubSub:
		publisher, err := cloudpubsub.NewPublisher(ctx, cloudpubsub.PublisherConfig{
			ProjectID: cfg.pubsub.projectID,
			TopicID:   cfg.pubsub.topicID,
		})
		if err != nil {
			return nil, err
		}
		return &readingSink{
			writer:      publisher,
			description: fmt.Sprintf("pubsub publisher project=%s topic=%s", cfg.pubsub.projectID, cfg.pubsub.topicID),
			close: func() {
				if err := publisher.Close(); err != nil {
					logger.Printf("close pubsub publisher: %v", err)
				}
			},
		}, nil
	default:
		return nil, fmt.Errorf("unsupported ingestion sink %q", cfg.ingestionSink)
	}
}

func runPoll(ctx context.Context, poller *openaq.Poller, logger *log.Logger) {
	stats, err := poller.PollOnce(ctx)
	if err != nil {
		logger.Printf("poll failed: %v", err)
		return
	}
	logger.Printf(
		"poll complete locations=%d measurements=%d published=%d skipped=%d",
		stats.Locations,
		stats.Measurements,
		stats.Published,
		stats.Skipped,
	)
}

func loadQueueConfig() (buffer.Config, error) {
	capacity, err := envInt("BACKPRESSURE_CHANNEL_CAPACITY", 10000)
	if err != nil {
		return buffer.Config{}, err
	}
	batchSize, err := envInt("QUEUE_BATCH_SIZE", 100)
	if err != nil {
		return buffer.Config{}, err
	}
	flushMillis, err := envInt("QUEUE_FLUSH_INTERVAL_MS", 1000)
	if err != nil {
		return buffer.Config{}, err
	}

	return buffer.Config{
		Capacity:      capacity,
		BatchSize:     batchSize,
		FlushInterval: time.Duration(flushMillis) * time.Millisecond,
	}, nil
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
