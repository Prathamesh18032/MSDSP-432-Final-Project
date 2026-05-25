package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/coldstore"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/timescale"
)

const (
	defaultDSN           = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"
	exportModeRetention  = "retention"
	exportModeAll        = "all"
	defaultColdRoot      = "data/cold"
	defaultRetentionHour = 72
	defaultBatchSize     = 1000
	storageTargetLocal   = "local"
	storageTargetGCS     = "gcs"
)

type config struct {
	dsn            string
	root           string
	mode           string
	retentionHours int
	batchSize      int
	storageTarget  string
	gcsBucket      string
	keepLocal      bool
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("load cold export config: %v", err)
	}

	started := time.Now().UTC()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	writer, err := timescale.Connect(ctx, cfg.dsn)
	if err != nil {
		log.Fatalf("connect to TimescaleDB: %v", err)
	}
	defer writer.Close()

	query := timescale.ExportReadingsQuery{Limit: cfg.batchSize}
	windowLabel := "all readings"
	if cfg.mode == exportModeRetention {
		cutoff := started.Add(-time.Duration(cfg.retentionHours) * time.Hour)
		query.Before = &cutoff
		windowLabel = fmt.Sprintf("readings before %s", cutoff.Format(time.RFC3339))
	}

	batch, err := writer.ExportReadings(ctx, query)
	if err != nil {
		log.Fatalf("query cold export readings: %v", err)
	}
	if len(batch) == 0 {
		fmt.Printf("No readings matched cold export window (%s). TimescaleDB rows were not modified.\n", windowLabel)
		return
	}

	results, err := coldstore.WriteSensorReadings(cfg.root, batch, started)
	if err != nil {
		log.Fatalf("write cold Parquet files: %v", err)
	}

	elapsed := time.Since(started)
	fmt.Printf("Exported %d readings into %d Parquet file(s) from %s in %s. TimescaleDB rows were not modified.\n", len(batch), len(results), windowLabel, elapsed.Round(time.Millisecond))
	for _, result := range results {
		fmt.Printf("- %s (%d rows)\n", result.Path, result.Rows)
	}

	if cfg.storageTarget == storageTargetGCS {
		uploadStarted := time.Now().UTC()
		uploads, err := coldstore.UploadSensorReadingFiles(ctx, cfg.root, cfg.gcsBucket, results)
		if err != nil {
			log.Fatalf("upload cold Parquet files to GCS: %v", err)
		}
		fmt.Printf("Uploaded %d Parquet file(s) to gs://%s in %s.\n", len(uploads), cfg.gcsBucket, time.Since(uploadStarted).Round(time.Millisecond))
		for _, upload := range uploads {
			fmt.Printf("- %s (%d rows)\n", upload.URI, upload.Rows)
		}
		if !cfg.keepLocal {
			for _, upload := range uploads {
				if err := os.Remove(upload.LocalPath); err != nil {
					log.Printf("remove local cold export file %s: %v", upload.LocalPath, err)
				}
			}
		}
	}
}

func loadConfig() (config, error) {
	return loadConfigFromArgs(os.Args[1:])
}

func loadConfigFromArgs(args []string) (config, error) {
	mode := envOrDefault("COLD_EXPORT_MODE", exportModeRetention)
	if mode != exportModeRetention && mode != exportModeAll {
		return config{}, fmt.Errorf("COLD_EXPORT_MODE must be %q or %q", exportModeRetention, exportModeAll)
	}

	retentionHours, err := envInt("COLD_EXPORT_HOT_RETENTION_HOURS", defaultRetentionHour)
	if err != nil {
		return config{}, err
	}
	if retentionHours <= 0 {
		return config{}, fmt.Errorf("COLD_EXPORT_HOT_RETENTION_HOURS must be positive")
	}

	batchSize, err := envInt("COLD_EXPORT_BATCH_SIZE", defaultBatchSize)
	if err != nil {
		return config{}, err
	}
	if batchSize <= 0 {
		return config{}, fmt.Errorf("COLD_EXPORT_BATCH_SIZE must be positive")
	}

	cfg := config{
		dsn:            envOrDefault("TIMESCALE_DSN", defaultDSN),
		root:           envOrDefault("COLD_STORAGE_ROOT", defaultColdRoot),
		mode:           mode,
		retentionHours: retentionHours,
		batchSize:      batchSize,
		storageTarget:  envOrDefault("COLD_STORAGE_TARGET", storageTargetLocal),
		gcsBucket:      os.Getenv("GCS_BUCKET"),
		keepLocal:      envBool("CLOUD_COLD_EXPORT_KEEP_LOCAL", true),
	}

	flags := flag.NewFlagSet("export-cold", flag.ContinueOnError)
	flags.StringVar(&cfg.dsn, "dsn", cfg.dsn, "TimescaleDB/PostgreSQL connection string")
	flags.StringVar(&cfg.root, "root", cfg.root, "local cold storage root")
	flags.StringVar(&cfg.mode, "mode", cfg.mode, "cold export mode: retention or all")
	flags.IntVar(&cfg.retentionHours, "retention-hours", cfg.retentionHours, "hot retention window in hours for retention mode")
	flags.IntVar(&cfg.batchSize, "batch-size", cfg.batchSize, "maximum readings to export in one run")
	flags.StringVar(&cfg.storageTarget, "target", cfg.storageTarget, "cold storage target: local or gcs")
	flags.StringVar(&cfg.gcsBucket, "gcs-bucket", cfg.gcsBucket, "GCS bucket for cloud cold storage uploads")
	if err := flags.Parse(args); err != nil {
		return config{}, err
	}

	if cfg.mode != exportModeRetention && cfg.mode != exportModeAll {
		return config{}, fmt.Errorf("mode must be %q or %q", exportModeRetention, exportModeAll)
	}
	if cfg.retentionHours <= 0 {
		return config{}, fmt.Errorf("retention-hours must be positive")
	}
	if cfg.batchSize <= 0 {
		return config{}, fmt.Errorf("batch-size must be positive")
	}
	if cfg.root == "" {
		return config{}, fmt.Errorf("cold storage root is required")
	}
	if cfg.storageTarget != storageTargetLocal && cfg.storageTarget != storageTargetGCS {
		return config{}, fmt.Errorf("target must be %q or %q", storageTargetLocal, storageTargetGCS)
	}
	if cfg.storageTarget == storageTargetGCS && cfg.gcsBucket == "" {
		return config{}, fmt.Errorf("GCS_BUCKET is required when COLD_STORAGE_TARGET=gcs")
	}

	return cfg, nil
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

func envBool(name string, fallback bool) bool {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}
