package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
)

const (
	defaultDSN          = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"
	defaultDatabase     = "smartcity_hot"
	defaultBackupPrefix = "backups/timescaledb"
	defaultLocalRoot    = "/tmp/smartcity-backups"
	defaultTimeoutSec   = 600
)

type config struct {
	dsn        string
	bucket     string
	prefix     string
	database   string
	localRoot  string
	timeoutSec int
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("load backup config: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(cfg.timeoutSec)*time.Second)
	defer cancel()

	started := time.Now().UTC()
	objectName := backupObjectName(cfg.prefix, cfg.database, started)
	localPath := filepath.Join(cfg.localRoot, filepath.Base(objectName))

	if err := os.MkdirAll(cfg.localRoot, 0o755); err != nil {
		log.Fatalf("create backup directory: %v", err)
	}

	if err := runPgDump(ctx, cfg.dsn, localPath); err != nil {
		log.Fatalf("run pg_dump: %v", err)
	}

	info, err := os.Stat(localPath)
	if err != nil {
		log.Fatalf("stat backup file: %v", err)
	}

	uri, err := uploadBackup(ctx, cfg.bucket, objectName, localPath)
	if err != nil {
		log.Fatalf("upload backup: %v", err)
	}

	if err := os.Remove(localPath); err != nil {
		log.Printf("remove local backup file %s: %v", localPath, err)
	}

	fmt.Printf("Uploaded TimescaleDB backup to %s (%d bytes) in %s.\n", uri, info.Size(), time.Since(started).Round(time.Millisecond))
}

func loadConfig() (config, error) {
	timeoutSec, err := envInt("TIMESCALE_BACKUP_TIMEOUT_SECONDS", defaultTimeoutSec)
	if err != nil {
		return config{}, err
	}

	cfg := config{
		dsn:        envOrDefault("TIMESCALE_DSN", defaultDSN),
		bucket:     os.Getenv("GCS_BUCKET"),
		prefix:     strings.Trim(envOrDefault("TIMESCALE_BACKUP_PREFIX", defaultBackupPrefix), "/"),
		database:   envOrDefault("K8S_TIMESCALE_DB", defaultDatabase),
		localRoot:  envOrDefault("TIMESCALE_BACKUP_LOCAL_ROOT", defaultLocalRoot),
		timeoutSec: timeoutSec,
	}

	if cfg.dsn == "" {
		return config{}, fmt.Errorf("TIMESCALE_DSN is required")
	}
	if cfg.bucket == "" {
		return config{}, fmt.Errorf("GCS_BUCKET is required")
	}
	if cfg.prefix == "" {
		return config{}, fmt.Errorf("TIMESCALE_BACKUP_PREFIX is required")
	}
	if cfg.database == "" {
		return config{}, fmt.Errorf("K8S_TIMESCALE_DB is required")
	}
	if cfg.localRoot == "" {
		return config{}, fmt.Errorf("TIMESCALE_BACKUP_LOCAL_ROOT is required")
	}
	if cfg.timeoutSec <= 0 {
		return config{}, fmt.Errorf("TIMESCALE_BACKUP_TIMEOUT_SECONDS must be positive")
	}
	return cfg, nil
}

func backupObjectName(prefix string, database string, timestamp time.Time) string {
	ts := timestamp.UTC()
	db := partitionSafe(database)
	return fmt.Sprintf("%s/year=%04d/month=%02d/day=%02d/%s-%s.dump",
		strings.Trim(prefix, "/"),
		ts.Year(),
		int(ts.Month()),
		ts.Day(),
		db,
		ts.Format("20060102T150405Z"),
	)
}

func runPgDump(ctx context.Context, dsn string, outputPath string) error {
	pgDump, err := exec.LookPath("pg_dump")
	if err != nil {
		return fmt.Errorf("pg_dump not found in PATH: %w", err)
	}
	cmd := exec.CommandContext(ctx, pgDump, "--format=custom", "--no-owner", "--no-acl", "--file", outputPath, dsn)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func uploadBackup(ctx context.Context, bucketName string, objectName string, localPath string) (string, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("create GCS client: %w", err)
	}
	defer client.Close()

	file, err := os.Open(localPath)
	if err != nil {
		return "", fmt.Errorf("open backup file: %w", err)
	}
	defer file.Close()

	writer := client.Bucket(bucketName).Object(objectName).NewWriter(ctx)
	writer.ContentType = "application/octet-stream"
	if _, err := io.Copy(writer, file); err != nil {
		_ = writer.Close()
		return "", fmt.Errorf("write GCS object: %w", err)
	}
	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("close GCS object: %w", err)
	}
	return "gs://" + bucketName + "/" + objectName, nil
}

func partitionSafe(value string) string {
	replacer := strings.NewReplacer("/", "-", "\\", "-", " ", "_", ":", "-")
	return replacer.Replace(value)
}

func envOrDefault(name string, fallback string) string {
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
