package main

import (
	"testing"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/cloudpubsub"
)

func TestLoadConfigUsesDefaults(t *testing.T) {
	t.Setenv("GCP_PROJECT_ID", "smartcity-project")
	t.Setenv("GCP_PUBSUB_SUBSCRIPTION", "")
	t.Setenv("PUBSUB_MAX_MESSAGES", "")
	t.Setenv("PUBSUB_CONSUME_LIMIT", "")
	t.Setenv("PUBSUB_CONSUME_TIMEOUT_SECONDS", "")
	t.Setenv("TIMESCALE_DSN", "")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.subscriptionID != cloudpubsub.DefaultSubscriptionID {
		t.Fatalf("subscription = %q", cfg.subscriptionID)
	}
	if cfg.maxMessages != cloudpubsub.DefaultMaxMessages {
		t.Fatalf("max messages = %d", cfg.maxMessages)
	}
	if cfg.timescaleDSN != defaultTimescaleDSN {
		t.Fatalf("Timescale DSN = %q", cfg.timescaleDSN)
	}
	if cfg.consumeLimit != 0 || cfg.consumeTimeout != 0 {
		t.Fatalf("bounded consume defaults = limit %d timeout %s", cfg.consumeLimit, cfg.consumeTimeout)
	}
}

func TestLoadConfigRequiresProject(t *testing.T) {
	t.Setenv("GCP_PROJECT_ID", "")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected missing project error")
	}
}

func TestLoadConfigRejectsInvalidMaxMessages(t *testing.T) {
	t.Setenv("GCP_PROJECT_ID", "smartcity-project")
	t.Setenv("PUBSUB_MAX_MESSAGES", "not-an-int")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected max messages error")
	}
}

func TestLoadConfigUsesBoundedConsumeConfig(t *testing.T) {
	t.Setenv("GCP_PROJECT_ID", "smartcity-project")
	t.Setenv("PUBSUB_CONSUME_LIMIT", "10")
	t.Setenv("PUBSUB_CONSUME_TIMEOUT_SECONDS", "60")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if cfg.consumeLimit != 10 {
		t.Fatalf("consume limit = %d", cfg.consumeLimit)
	}
	if cfg.consumeTimeout.Seconds() != 60 {
		t.Fatalf("consume timeout = %s", cfg.consumeTimeout)
	}
}

func TestLoadConfigRejectsInvalidConsumeLimit(t *testing.T) {
	t.Setenv("GCP_PROJECT_ID", "smartcity-project")
	t.Setenv("PUBSUB_CONSUME_LIMIT", "-1")

	if _, err := loadConfig(); err == nil {
		t.Fatal("expected consume limit error")
	}
}
