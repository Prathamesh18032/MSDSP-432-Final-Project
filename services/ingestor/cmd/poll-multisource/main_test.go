package main

import "testing"

func TestLoadConfigUsesMultiSourceDefaults(t *testing.T) {
	t.Setenv("OPENAQ_API_KEY", "")
	t.Setenv("MULTISOURCE_POLL_INTERVAL_SECONDS", "")
	t.Setenv("OPENMETEO_BASE_URL", "")
	t.Setenv("OPENMETEO_COORDINATES", "")
	t.Setenv("GBFS_DISCOVERY_URL", "")
	t.Setenv("GBFS_LANGUAGE", "")
	t.Setenv("GBFS_STATION_LIMIT", "")
	t.Setenv("USGS_BASE_URL", "")
	t.Setenv("USGS_SITE_IDS", "")
	t.Setenv("USGS_PARAMETER_CODES", "")
	t.Setenv("BACKPRESSURE_CHANNEL_CAPACITY", "")
	t.Setenv("QUEUE_BATCH_SIZE", "")
	t.Setenv("QUEUE_FLUSH_INTERVAL_MS", "")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.openAQ.apiKey != "" {
		t.Fatalf("OpenAQ key = %q, want empty optional key", cfg.openAQ.apiKey)
	}
	if cfg.openMeteo.coordinates != "41.8781,-87.6298" {
		t.Fatalf("Open-Meteo coordinates = %q", cfg.openMeteo.coordinates)
	}
	if cfg.gbfs.stationLimit != 25 {
		t.Fatalf("GBFS station limit = %d", cfg.gbfs.stationLimit)
	}
	if cfg.usgs.siteIDs != "05536123" {
		t.Fatalf("USGS site IDs = %q", cfg.usgs.siteIDs)
	}
	if cfg.queue.Capacity != 10000 || cfg.queue.BatchSize != 100 {
		t.Fatalf("queue defaults = %+v", cfg.queue)
	}
	if cfg.ingestionSink != sinkLocal {
		t.Fatalf("ingestion sink = %q", cfg.ingestionSink)
	}
}

func TestLoadConfigRejectsInvalidPollInterval(t *testing.T) {
	t.Setenv("MULTISOURCE_POLL_INTERVAL_SECONDS", "0")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid interval error")
	}
}

func TestLoadConfigRejectsInvalidStationLimit(t *testing.T) {
	t.Setenv("GBFS_STATION_LIMIT", "-1")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid station limit error")
	}
}

func TestLoadConfigRejectsInvalidIngestionSink(t *testing.T) {
	t.Setenv("INGESTION_SINK", "unknown")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid ingestion sink error")
	}
}

func TestLoadConfigAllowsPubSubSink(t *testing.T) {
	t.Setenv("INGESTION_SINK", sinkPubSub)
	t.Setenv("GCP_PROJECT_ID", "smartcity-project")
	t.Setenv("GCP_PUBSUB_TOPIC", "")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.ingestionSink != sinkPubSub {
		t.Fatalf("ingestion sink = %q", cfg.ingestionSink)
	}
	if cfg.pubsub.projectID != "smartcity-project" {
		t.Fatalf("project ID = %q", cfg.pubsub.projectID)
	}
	if cfg.pubsub.topicID == "" {
		t.Fatal("expected default topic ID")
	}
}
