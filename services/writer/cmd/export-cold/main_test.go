package main

import "testing"

func TestLoadConfigDefaults(t *testing.T) {
	t.Setenv("TIMESCALE_DSN", "")
	t.Setenv("COLD_STORAGE_ROOT", "")
	t.Setenv("COLD_EXPORT_MODE", "")
	t.Setenv("COLD_EXPORT_HOT_RETENTION_HOURS", "")
	t.Setenv("COLD_EXPORT_BATCH_SIZE", "")

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
