package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/buffer"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/simulator"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/timescale"
)

const defaultDSN = "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"

func main() {
	var samplesPerSensor int
	var dsn string

	flag.IntVar(&samplesPerSensor, "samples-per-sensor", 3, "number of timestamp samples to generate per sensor")
	flag.StringVar(&dsn, "dsn", envOrDefault("TIMESCALE_DSN", defaultDSN), "TimescaleDB/PostgreSQL connection string")
	flag.Parse()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	reference := time.Now().UTC().Truncate(time.Minute)
	batch := simulator.New().GenerateBatch(reference, samplesPerSensor)

	for _, reading := range batch {
		if err := readings.Validate(reading, reference); err != nil {
			log.Fatalf("generated invalid reading %s: %v", reading.DedupKey(), err)
		}
	}

	writer, err := timescale.Connect(ctx, dsn)
	if err != nil {
		log.Fatalf("connect to TimescaleDB: %v", err)
	}
	defer writer.Close()

	queueConfig, err := loadQueueConfig()
	if err != nil {
		log.Fatalf("load queue config: %v", err)
	}
	queue, err := buffer.NewQueue(writer, writer, queueConfig)
	if err != nil {
		log.Fatalf("create local buffer: %v", err)
	}
	queue.Start(context.Background())

	result := queue.PublishBatch(batch)
	closeCtx, closeCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer closeCancel()
	if err := queue.Close(closeCtx); err != nil {
		log.Fatalf("flush simulator readings: %v", err)
	}

	stats := queue.Stats()
	fmt.Printf("Published %d simulator readings to local buffer, dropped %d, flushed %d to TimescaleDB.\n", result.Accepted, result.Dropped, stats.Flushed)
}

func envOrDefault(name, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	return value
}

func loadQueueConfig() (buffer.Config, error) {
	capacity, err := envInt("BACKPRESSURE_CHANNEL_CAPACITY", 10000)
	if err != nil {
		return buffer.Config{}, err
	}
	batchSize, err := envInt("QUEUE_BATCH_SIZE", 100)
	if err != nil {
		return buffer.Config{}, err
	}
	flushMillis, err := envInt("QUEUE_FLUSH_INTERVAL_MS", 1000)
	if err != nil {
		return buffer.Config{}, err
	}

	return buffer.Config{
		Capacity:      capacity,
		BatchSize:     batchSize,
		FlushInterval: time.Duration(flushMillis) * time.Millisecond,
	}, nil
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
