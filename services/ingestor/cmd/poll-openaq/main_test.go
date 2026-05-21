package main

import "testing"

func TestLoadConfigRequiresAPIKey(t *testing.T) {
	t.Setenv("OPENAQ_API_KEY", "")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected missing API key error")
	}
}

func TestLoadConfigUsesDefaults(t *testing.T) {
	t.Setenv("OPENAQ_API_KEY", "test-key")
	t.Setenv("OPENAQ_BASE_URL", "")
	t.Setenv("OPENAQ_COORDINATES", "")
	t.Setenv("OPENAQ_RADIUS_METERS", "")
	t.Setenv("OPENAQ_LOCATION_LIMIT", "")
	t.Setenv("OPENAQ_POLL_INTERVAL_SECONDS", "")
	t.Setenv("TIMESCALE_DSN", "")
	t.Setenv("BACKPRESSURE_CHANNEL_CAPACITY", "")
	t.Setenv("QUEUE_BATCH_SIZE", "")
	t.Setenv("QUEUE_FLUSH_INTERVAL_MS", "")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.coordinates != "41.8781,-87.6298" {
		t.Fatalf("coordinates = %q", cfg.coordinates)
	}
	if cfg.radiusMeters != 25000 {
		t.Fatalf("radiusMeters = %d", cfg.radiusMeters)
	}
	if cfg.locationLimit != 5 {
		t.Fatalf("locationLimit = %d", cfg.locationLimit)
	}
	if cfg.queue.Capacity != 10000 {
		t.Fatalf("queue capacity = %d", cfg.queue.Capacity)
	}
	if cfg.queue.BatchSize != 100 {
		t.Fatalf("queue batch size = %d", cfg.queue.BatchSize)
	}
}

func TestLoadConfigRejectsInvalidRadius(t *testing.T) {
	t.Setenv("OPENAQ_API_KEY", "test-key")
	t.Setenv("OPENAQ_RADIUS_METERS", "25001")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid radius error")
	}
}

func TestLoadConfigRejectsInvalidQueueConfig(t *testing.T) {
	t.Setenv("OPENAQ_API_KEY", "test-key")
	t.Setenv("QUEUE_BATCH_SIZE", "not-an-int")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid queue config error")
	}
}
