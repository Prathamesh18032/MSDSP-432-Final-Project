package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/cloudpubsub"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/timescale"
)

const defaultTimescaleDSN = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"

func main() {
	logger := log.New(os.Stdout, "pubsub-consumer ", log.LstdFlags|log.LUTC)

	cfg, err := loadConfig()
	if err != nil {
		logger.Fatalf("load config: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	writer, err := timescale.Connect(ctx, cfg.timescaleDSN)
	if err != nil {
		logger.Fatalf("connect to TimescaleDB: %v", err)
	}
	defer writer.Close()

	consumer, err := cloudpubsub.NewConsumer(ctx, cloudpubsub.ConsumerConfig{
		ProjectID:      cfg.projectID,
		SubscriptionID: cfg.subscriptionID,
		MaxMessages:    cfg.maxMessages,
	}, writer, logger)
	if err != nil {
		logger.Fatalf("create Pub/Sub consumer: %v", err)
	}
	defer consumer.Close()

	logger.Printf(
		"starting Pub/Sub consumer project=%s subscription=%s max_messages=%d",
		cfg.projectID,
		cfg.subscriptionID,
		cfg.maxMessages,
	)
	if err := consumer.Receive(ctx); err != nil && !errors.Is(ctx.Err(), context.Canceled) {
		logger.Fatalf("receive Pub/Sub messages: %v", err)
	}
	logger.Print("stopping Pub/Sub consumer")
}

type config struct {
	projectID      string
	subscriptionID string
	maxMessages    int
	timescaleDSN   string
}

func loadConfig() (config, error) {
	maxMessages, err := envInt("PUBSUB_MAX_MESSAGES", cloudpubsub.DefaultMaxMessages)
	if err != nil {
		return config{}, err
	}

	cfg := config{
		projectID:      os.Getenv("GCP_PROJECT_ID"),
		subscriptionID: envOrDefault("GCP_PUBSUB_SUBSCRIPTION", cloudpubsub.DefaultSubscriptionID),
		maxMessages:    maxMessages,
		timescaleDSN:   envOrDefault("TIMESCALE_DSN", defaultTimescaleDSN),
	}
	if err := (cloudpubsub.ConsumerConfig{
		ProjectID:      cfg.projectID,
		SubscriptionID: cfg.subscriptionID,
		MaxMessages:    cfg.maxMessages,
	}).Validate(); err != nil {
		return config{}, err
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
