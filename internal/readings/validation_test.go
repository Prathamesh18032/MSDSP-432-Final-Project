package readings

import (
	"strings"
	"testing"
	"time"
)

func validReading(reference time.Time) SensorReading {
	return SensorReading{
		Time:          reference.UTC(),
		SensorID:      "SIM-CHI-AQ-001",
		Metric:        "PM2.5",
		Value:         12.3,
		Unit:          "ug/m3",
		Source:        SourceSimulator,
		Latitude:      41.8864,
		Longitude:     -87.6246,
		QualityFlag:   QualityValid,
		IngestedAt:    reference.UTC(),
		SchemaVersion: SchemaVersion,
	}
}

func TestValidateAcceptsValidReading(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)

	if err := Validate(validReading(reference), reference); err != nil {
		t.Fatalf("expected valid reading, got %v", err)
	}
}

func TestValidateRejectsMissingRequiredFields(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	reading := validReading(reference)
	reading.SensorID = ""
	reading.Unit = ""

	err := Validate(reading, reference)
	if err == nil {
		t.Fatal("expected validation error")
	}
	if !strings.Contains(err.Error(), "sensor_id is required") {
		t.Fatalf("expected sensor_id error, got %v", err)
	}
	if !strings.Contains(err.Error(), "unit is required") {
		t.Fatalf("expected unit error, got %v", err)
	}
}

func TestValidateRejectsStaleTimestamp(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	reading := validReading(reference)
	reading.Time = reference.Add(-10 * time.Minute)

	if err := Validate(reading, reference); err == nil {
		t.Fatal("expected stale timestamp error")
	}
}

func TestValidateRejectsInvalidMetricRange(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	reading := validReading(reference)
	reading.Value = 2000

	err := Validate(reading, reference)
	if err == nil {
		t.Fatal("expected range error")
	}
	if !strings.Contains(err.Error(), "PM2.5 value") {
		t.Fatalf("expected PM2.5 range error, got %v", err)
	}
}

func TestValidateAcceptsMultiSourceMetrics(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	cases := []struct {
		name   string
		source string
		metric string
		value  float64
		unit   string
	}{
		{name: "openmeteo wind", source: SourceOpenMeteo, metric: "wind_speed", value: 17.2, unit: "km/h"},
		{name: "openmeteo precipitation", source: SourceOpenMeteo, metric: "precipitation", value: 1.5, unit: "mm"},
		{name: "gbfs bikes", source: SourceGBFS, metric: "bike_available_count", value: 8, unit: "count"},
		{name: "gbfs docks", source: SourceGBFS, metric: "dock_available_count", value: 12, unit: "count"},
		{name: "gbfs capacity", source: SourceGBFS, metric: "station_capacity", value: 20, unit: "count"},
		{name: "usgs gage", source: SourceUSGS, metric: "water_gage_height", value: 2.7, unit: "ft"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			reading := validReading(reference)
			reading.Source = tc.source
			reading.Metric = tc.metric
			reading.Value = tc.value
			reading.Unit = tc.unit

			if err := Validate(reading, reference); err != nil {
				t.Fatalf("expected valid %s reading, got %v", tc.metric, err)
			}
		})
	}
}

func TestValidateRejectsInvalidCoordinates(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	reading := validReading(reference)
	reading.Latitude = 100

	if err := Validate(reading, reference); err == nil {
		t.Fatal("expected coordinate error")
	}
}

func TestDedupKeyUsesSensorTimeMetric(t *testing.T) {
	reference := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	reading := validReading(reference)

	got := reading.DedupKey()
	want := "SIM-CHI-AQ-001|2026-05-20T12:00:00Z|PM2.5"
	if got != want {
		t.Fatalf("DedupKey() = %q, want %q", got, want)
	}
}
