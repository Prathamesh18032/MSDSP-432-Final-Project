package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

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

	if err := writer.InsertReadings(ctx, batch); err != nil {
		log.Fatalf("insert simulator readings: %v", err)
	}

	fmt.Printf("Inserted %d simulator readings into TimescaleDB.\n", len(batch))
}

func envOrDefault(name, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	return value
}
