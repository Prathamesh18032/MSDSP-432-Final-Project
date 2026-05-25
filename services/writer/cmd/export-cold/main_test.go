package main

import "testing"

func TestLoadConfigDefaults(t *testing.T) {
	t.Setenv("TIMESCALE_DSN", "")
	t.Setenv("COLD_STORAGE_ROOT", "")
	t.Setenv("COLD_STORAGE_TARGET", "")
	t.Setenv("COLD_EXPORT_MODE", "")
	t.Setenv("COLD_EXPORT_HOT_RETENTION_HOURS", "")
	t.Setenv("COLD_EXPORT_BATCH_SIZE", "")
	t.Setenv("GCS_BUCKET", "")
	t.Setenv("CLOUD_COLD_EXPORT_KEEP_LOCAL", "")

	cfg, err := loadConfigFromArgs(nil)
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.mode != exportModeRetention {
		t.Fatalf("cfg.mode = %q, want %q", cfg.mode, exportModeRetention)
	}
	if cfg.root != defaultColdRoot {
		t.Fatalf("cfg.root = %q, want %q", cfg.root, defaultColdRoot)
	}
	if cfg.retentionHours != defaultRetentionHour {
		t.Fatalf("cfg.retentionHours = %d, want %d", cfg.retentionHours, defaultRetentionHour)
	}
	if cfg.batchSize != defaultBatchSize {
		t.Fatalf("cfg.batchSize = %d, want %d", cfg.batchSize, defaultBatchSize)
	}
	if cfg.storageTarget != storageTargetLocal {
		t.Fatalf("cfg.storageTarget = %q, want %q", cfg.storageTarget, storageTargetLocal)
	}
	if !cfg.keepLocal {
		t.Fatal("cfg.keepLocal = false, want true")
	}
}

func TestLoadConfigRejectsInvalidValues(t *testing.T) {
	tests := []struct {
		name  string
		env   string
		value string
	}{
		{name: "mode", env: "COLD_EXPORT_MODE", value: "invalid"},
		{name: "retention hours", env: "COLD_EXPORT_HOT_RETENTION_HOURS", value: "0"},
		{name: "batch size", env: "COLD_EXPORT_BATCH_SIZE", value: "-1"},
		{name: "storage target", env: "COLD_STORAGE_TARGET", value: "invalid"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("COLD_EXPORT_MODE", "")
			t.Setenv("COLD_EXPORT_HOT_RETENTION_HOURS", "")
			t.Setenv("COLD_EXPORT_BATCH_SIZE", "")
			t.Setenv(tt.env, tt.value)

			if _, err := loadConfigFromArgs(nil); err == nil {
				t.Fatal("expected config validation error")
			}
		})
	}
}

func TestLoadConfigRequiresBucketForGCS(t *testing.T) {
	t.Setenv("COLD_STORAGE_TARGET", "gcs")
	t.Setenv("GCS_BUCKET", "")

	if _, err := loadConfigFromArgs(nil); err == nil {
		t.Fatal("expected missing GCS bucket error")
	}
}

func TestLoadConfigUsesGCSSettings(t *testing.T) {
	t.Setenv("COLD_STORAGE_TARGET", "gcs")
	t.Setenv("GCS_BUCKET", "smartcity-zero-disk-iot-pa-cold")
	t.Setenv("CLOUD_COLD_EXPORT_KEEP_LOCAL", "false")

	cfg, err := loadConfigFromArgs([]string{"-target", "local"})
	if err != nil {
		t.Fatalf("loadConfigFromArgs() error = %v", err)
	}
	if cfg.storageTarget != storageTargetLocal {
		t.Fatalf("cfg.storageTarget = %q, want %q", cfg.storageTarget, storageTargetLocal)
	}
	if cfg.gcsBucket != "smartcity-zero-disk-iot-pa-cold" {
		t.Fatalf("cfg.gcsBucket = %q", cfg.gcsBucket)
	}
	if cfg.keepLocal {
		t.Fatal("cfg.keepLocal = true, want false")
	}
}
