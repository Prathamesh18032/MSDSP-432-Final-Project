package main

import (
	"testing"
	"time"
)

func TestBackupObjectName(t *testing.T) {
	timestamp := time.Date(2026, 5, 25, 8, 30, 45, 0, time.UTC)
	got := backupObjectName("backups/timescaledb", "smartcity_hot", timestamp)
	want := "backups/timescaledb/year=2026/month=05/day=25/smartcity_hot-20260525T083045Z.dump"
	if got != want {
		t.Fatalf("backupObjectName() = %q, want %q", got, want)
	}
}

func TestLoadConfigRequiresBucket(t *testing.T) {
	t.Setenv("GCS_BUCKET", "")
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected missing bucket error")
	}
}

func TestLoadConfigRejectsInvalidTimeout(t *testing.T) {
	t.Setenv("GCS_BUCKET", "smartcity-cold")
	t.Setenv("TIMESCALE_BACKUP_TIMEOUT_SECONDS", "0")
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected invalid timeout error")
	}
}

func TestLoadConfigUsesEnv(t *testing.T) {
	t.Setenv("TIMESCALE_DSN", "postgres://example")
	t.Setenv("GCS_BUCKET", "smartcity-cold")
	t.Setenv("TIMESCALE_BACKUP_PREFIX", "custom/backups")
	t.Setenv("K8S_TIMESCALE_DB", "city_hot")
	t.Setenv("TIMESCALE_BACKUP_LOCAL_ROOT", "/tmp/backups")
	t.Setenv("TIMESCALE_BACKUP_TIMEOUT_SECONDS", "30")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.dsn != "postgres://example" || cfg.bucket != "smartcity-cold" || cfg.prefix != "custom/backups" || cfg.database != "city_hot" || cfg.localRoot != "/tmp/backups" || cfg.timeoutSec != 30 {
		t.Fatalf("unexpected config: %+v", cfg)
	}
}
