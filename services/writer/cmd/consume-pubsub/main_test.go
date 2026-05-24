package main

import (
	"testing"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/cloudpubsub"
)

func TestLoadConfigUsesDefaults(t *testing.T) {
	t.Setenv("GCP_PROJECT_ID", "smartcity-project")
	t.Setenv("GCP_PUBSUB_SUBSCRIPTION", "")
	t.Setenv("PUBSUB_MAX_MESSAGES", "")
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
