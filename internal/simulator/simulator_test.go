package simulator

import (
	"reflect"
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func TestGenerateBatchShapeAndStableSensorIDs(t *testing.T) {
	sim := New()
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)

	batch := sim.GenerateBatch(reference, 2)
	if len(batch) != 30 {
		t.Fatalf("len(batch) = %d, want 30", len(batch))
	}

	wantSensors := map[string]bool{
		"SIM-CHI-AQ-001": false,
		"SIM-CHI-AQ-002": false,
		"SIM-CHI-AQ-003": false,
	}
	for _, reading := range batch {
		if _, ok := wantSensors[reading.SensorID]; !ok {
			t.Fatalf("unexpected sensor id %q", reading.SensorID)
		}
		wantSensors[reading.SensorID] = true
	}
	for sensorID, seen := range wantSensors {
		if !seen {
			t.Fatalf("expected sensor %q in generated batch", sensorID)
		}
	}
}

func TestGenerateBatchIsDeterministic(t *testing.T) {
	sim := New()
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)

	first := sim.GenerateBatch(reference, 2)
	second := sim.GenerateBatch(reference, 2)
	if !reflect.DeepEqual(first, second) {
		t.Fatal("expected simulator output to be deterministic for the same reference time")
	}
}

func TestGenerateBatchProducesSupportedMetrics(t *testing.T) {
	sim := New()
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	batch := sim.GenerateBatch(reference, 1)

	wantMetrics := map[string]bool{
		"PM2.5":       false,
		"O3":          false,
		"NO2":         false,
		"temperature": false,
		"humidity":    false,
	}
	for _, reading := range batch {
		if !readings.IsSupportedMetric(reading.Metric) {
			t.Fatalf("unsupported metric %q", reading.Metric)
		}
		wantMetrics[reading.Metric] = true
	}
	for metric, seen := range wantMetrics {
		if !seen {
			t.Fatalf("expected metric %q in generated batch", metric)
		}
	}
}

func TestGenerateBatchReadingsValidate(t *testing.T) {
	sim := New()
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	batch := sim.GenerateBatch(reference, 1)

	for _, reading := range batch {
		if err := readings.Validate(reading, reference); err != nil {
			t.Fatalf("expected generated reading to validate: %+v: %v", reading, err)
		}
	}
}
