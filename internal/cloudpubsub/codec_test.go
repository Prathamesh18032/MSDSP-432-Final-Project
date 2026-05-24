package cloudpubsub

import (
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func testReading() readings.SensorReading {
	now := time.Date(2026, 5, 24, 12, 0, 0, 0, time.UTC)
	return readings.SensorReading{
		Time:          now,
		SensorID:      "openmeteo-chicago",
		Metric:        "temperature",
		Value:         22.5,
		Unit:          "C",
		Source:        readings.SourceOpenMeteo,
		Latitude:      41.8781,
		Longitude:     -87.6298,
		QualityFlag:   readings.QualityValid,
		IngestedAt:    now,
		SchemaVersion: readings.SchemaVersion,
	}
}

func TestEncodeDecodeReadingRoundTrip(t *testing.T) {
	reading := testReading()

	data, attributes, err := EncodeReading(reading)
	if err != nil {
		t.Fatalf("EncodeReading() error = %v", err)
	}

	if attributes[AttributeSchemaVersion] != "1" {
		t.Fatalf("schema attribute = %q", attributes[AttributeSchemaVersion])
	}
	if attributes[AttributeSource] != reading.Source {
		t.Fatalf("source attribute = %q", attributes[AttributeSource])
	}
	if attributes[AttributeMetric] != reading.Metric {
		t.Fatalf("metric attribute = %q", attributes[AttributeMetric])
	}
	if attributes[AttributeSensorID] != reading.SensorID {
		t.Fatalf("sensor attribute = %q", attributes[AttributeSensorID])
	}
	if attributes[AttributeDedupKey] != reading.DedupKey() {
		t.Fatalf("dedup attribute = %q", attributes[AttributeDedupKey])
	}

	got, err := DecodeReading(data)
	if err != nil {
		t.Fatalf("DecodeReading() error = %v", err)
	}
	if got.DedupKey() != reading.DedupKey() {
		t.Fatalf("DedupKey() = %q, want %q", got.DedupKey(), reading.DedupKey())
	}
	if got.Value != reading.Value || got.Unit != reading.Unit {
		t.Fatalf("decoded reading = %+v", got)
	}
}

func TestDecodeReadingRejectsInvalidJSON(t *testing.T) {
	if _, err := DecodeReading([]byte("{")); err == nil {
		t.Fatal("expected invalid JSON error")
	}
}
