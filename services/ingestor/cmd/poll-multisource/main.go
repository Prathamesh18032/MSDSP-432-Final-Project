package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/buffer"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/cloudpubsub"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/gbfs"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/openaq"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/openmeteo"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/timescale"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/usgs"
)

const defaultTimescaleDSN = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"
const (
	sinkLocal  = "local"
	sinkPubSub = "pubsub"
)

func main() {
	logger := log.New(os.Stdout, "multisource-poller ", log.LstdFlags|log.LUTC)
	once := flag.Bool("once", false, "poll all configured sources once, then exit")
	flag.Parse()

	cfg, err := loadConfig()
	if err != nil {
		logger.Fatalf("load config: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	sink, err := buildReadingSink(ctx, cfg, logger)
	if err != nil {
		logger.Fatalf("create reading sink: %v", err)
	}
	defer sink.close()

	pollers, err := buildPollers(cfg, sink.writer, logger)
	if err != nil {
		logger.Fatalf("create source pollers: %v", err)
	}

	logger.Printf("starting multi-source polling sources=%d interval=%s sink=%s", len(pollers), cfg.pollInterval, cfg.ingestionSink)
	logger.Print(sink.description)

	runAll(ctx, pollers, logger)
	if *once {
		logger.Print("one-shot multi-source poll complete")
		return
	}

	ticker := time.NewTicker(cfg.pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			logger.Print("stopping multi-source poller")
			return
		case <-ticker.C:
			runAll(ctx, pollers, logger)
		}
	}
}

type sourcePoller struct {
	name string
	run  func(context.Context) (string, error)
}

type readingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type readingSink struct {
	writer      readingWriter
	description string
	close       func()
}

type config struct {
	timescaleDSN  string
	ingestionSink string
	pollInterval  time.Duration
	queue         buffer.Config
	pubsub        pubsubConfig
	openAQ        openAQConfig
	openMeteo     openMeteoConfig
	gbfs          gbfsConfig
	usgs          usgsConfig
}

type pubsubConfig struct {
	projectID string
	topicID   string
}

type openAQConfig struct {
	apiKey        string
	baseURL       string
	coordinates   string
	radiusMeters  int
	locationLimit int
}

type openMeteoConfig struct {
	baseURL     string
	coordinates string
}

type gbfsConfig struct {
	discoveryURL string
	language     string
	stationLimit int
}

type usgsConfig struct {
	baseURL        string
	siteIDs        string
	parameterCodes string
}

func loadConfig() (config, error) {
	pollSeconds, err := envInt("MULTISOURCE_POLL_INTERVAL_SECONDS", 300)
	if err != nil {
		return config{}, err
	}
	if pollSeconds <= 0 {
		return config{}, fmt.Errorf("MULTISOURCE_POLL_INTERVAL_SECONDS must be positive")
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

	stationLimit, err := envInt("GBFS_STATION_LIMIT", 25)
	if err != nil {
		return config{}, err
	}
	if stationLimit < 0 {
		return config{}, fmt.Errorf("GBFS_STATION_LIMIT cannot be negative")
	}

	ingestionSink := envOrDefault("INGESTION_SINK", sinkLocal)
	if ingestionSink != sinkLocal && ingestionSink != sinkPubSub {
		return config{}, fmt.Errorf("INGESTION_SINK must be %q or %q", sinkLocal, sinkPubSub)
	}

	queueConfig, err := loadQueueConfig()
	if err != nil {
		return config{}, err
	}

	return config{
		timescaleDSN:  envOrDefault("TIMESCALE_DSN", defaultTimescaleDSN),
		ingestionSink: ingestionSink,
		pollInterval:  time.Duration(pollSeconds) * time.Second,
		queue:         queueConfig,
		pubsub: pubsubConfig{
			projectID: os.Getenv("GCP_PROJECT_ID"),
			topicID:   envOrDefault("GCP_PUBSUB_TOPIC", cloudpubsub.DefaultTopicID),
		},
		openAQ: openAQConfig{
			apiKey:        os.Getenv("OPENAQ_API_KEY"),
			baseURL:       envOrDefault("OPENAQ_BASE_URL", openaq.DefaultBaseURL),
			coordinates:   envOrDefault("OPENAQ_COORDINATES", "41.8781,-87.6298"),
			radiusMeters:  radiusMeters,
			locationLimit: locationLimit,
		},
		openMeteo: openMeteoConfig{
			baseURL:     envOrDefault("OPENMETEO_BASE_URL", openmeteo.DefaultBaseURL),
			coordinates: envOrDefault("OPENMETEO_COORDINATES", "41.8781,-87.6298"),
		},
		gbfs: gbfsConfig{
			discoveryURL: envOrDefault("GBFS_DISCOVERY_URL", gbfs.DefaultDiscoveryURL),
			language:     envOrDefault("GBFS_LANGUAGE", "en"),
			stationLimit: stationLimit,
		},
		usgs: usgsConfig{
			baseURL:        envOrDefault("USGS_BASE_URL", usgs.DefaultBaseURL),
			siteIDs:        envOrDefault("USGS_SITE_IDS", "05536123"),
			parameterCodes: envOrDefault("USGS_PARAMETER_CODES", "00065"),
		},
	}, nil
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

func buildPollers(cfg config, writer readingWriter, logger *log.Logger) ([]sourcePoller, error) {
	pollers := make([]sourcePoller, 0, 4)

	if cfg.openAQ.apiKey == "" {
		logger.Print("OPENAQ_API_KEY is empty; skipping OpenAQ in multi-source poller")
	} else {
		client, err := openaq.NewClient(cfg.openAQ.baseURL, cfg.openAQ.apiKey, nil)
		if err != nil {
			return nil, err
		}
		poller, err := openaq.NewPoller(client, writer, openaq.PollConfig{
			Coordinates:   cfg.openAQ.coordinates,
			RadiusMeters:  cfg.openAQ.radiusMeters,
			LocationLimit: cfg.openAQ.locationLimit,
		}, logger)
		if err != nil {
			return nil, err
		}
		pollers = append(pollers, sourcePoller{name: "openaq", run: func(ctx context.Context) (string, error) {
			stats, err := poller.PollOnce(ctx)
			return fmt.Sprintf("locations=%d measurements=%d published=%d skipped=%d", stats.Locations, stats.Measurements, stats.Published, stats.Skipped), err
		}})
	}

	openMeteoClient, err := openmeteo.NewClient(cfg.openMeteo.baseURL, nil)
	if err != nil {
		return nil, err
	}
	openMeteoPoller, err := openmeteo.NewPoller(openMeteoClient, writer, openmeteo.PollConfig{Coordinates: cfg.openMeteo.coordinates}, logger)
	if err != nil {
		return nil, err
	}
	pollers = append(pollers, sourcePoller{name: "openmeteo", run: func(ctx context.Context) (string, error) {
		stats, err := openMeteoPoller.PollOnce(ctx)
		return fmt.Sprintf("published=%d skipped=%d", stats.Published, stats.Skipped), err
	}})

	gbfsClient, err := gbfs.NewClient(cfg.gbfs.discoveryURL, cfg.gbfs.language, nil)
	if err != nil {
		return nil, err
	}
	gbfsPoller, err := gbfs.NewPoller(gbfsClient, writer, gbfs.PollConfig{StationLimit: cfg.gbfs.stationLimit}, logger)
	if err != nil {
		return nil, err
	}
	pollers = append(pollers, sourcePoller{name: "gbfs", run: func(ctx context.Context) (string, error) {
		stats, err := gbfsPoller.PollOnce(ctx)
		return fmt.Sprintf("stations=%d published=%d skipped=%d", stats.Stations, stats.Published, stats.Skipped), err
	}})

	usgsClient, err := usgs.NewClient(cfg.usgs.baseURL, nil)
	if err != nil {
		return nil, err
	}
	usgsPoller, err := usgs.NewPoller(usgsClient, writer, usgs.PollConfig{
		SiteIDs:        cfg.usgs.siteIDs,
		ParameterCodes: cfg.usgs.parameterCodes,
	}, logger)
	if err != nil {
		return nil, err
	}
	pollers = append(pollers, sourcePoller{name: "usgs", run: func(ctx context.Context) (string, error) {
		stats, err := usgsPoller.PollOnce(ctx)
		return fmt.Sprintf("time_series=%d published=%d skipped=%d", stats.TimeSeries, stats.Published, stats.Skipped), err
	}})

	return pollers, nil
}

func runAll(ctx context.Context, pollers []sourcePoller, logger *log.Logger) {
	for _, poller := range pollers {
		summary, err := poller.run(ctx)
		if err != nil {
			logger.Printf("%s poll failed: %v", poller.name, err)
			continue
		}
		logger.Printf("%s poll complete %s", poller.name, summary)
	}
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
