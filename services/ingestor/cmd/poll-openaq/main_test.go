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
}

func TestLoadConfigRejectsInvalidRadius(t *testing.T) {
	t.Setenv("OPENAQ_API_KEY", "test-key")
	t.Setenv("OPENAQ_RADIUS_METERS", "25001")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid radius error")
	}
}
