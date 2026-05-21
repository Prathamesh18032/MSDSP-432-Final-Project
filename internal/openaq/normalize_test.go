package openaq

import (
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func TestNormalizeMeasurementMapsPM25(t *testing.T) {
	lat, lon := 41.88, -87.63
	measurement := LatestMeasurement{
		DateTime:    DateTimeObject{UTC: time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)},
		Value:       12.3,
		Coordinates: Coordinates{Latitude: &lat, Longitude: &lon},
		SensorsID:   200,
		LocationID:  100,
	}
	sensor := SensorMeta{ID: 200, Parameter: Parameter{Name: "pm25"}, Units: "µg/m³"}

	reading, ok, reason := NormalizeMeasurement(measurement, sensor, measurement.DateTime.UTC)
	if !ok {
		t.Fatalf("expected reading, got skip reason %q", reason)
	}
	if reading.SensorID != "OPENAQ-200" || reading.Metric != "PM2.5" || reading.Unit != "ug/m3" || reading.Source != readings.SourceOpenAQ {
		t.Fatalf("unexpected reading: %+v", reading)
	}
	if err := readings.Validate(reading, reading.Time); err != nil {
		t.Fatalf("expected normalized reading to validate: %v", err)
	}
}

func TestNormalizeMeasurementSkipsUnsupportedMetric(t *testing.T) {
	measurement := LatestMeasurement{SensorsID: 200}
	sensor := SensorMeta{ID: 200, Parameter: Parameter{Name: "co"}, Units: "ppm"}

	if _, ok, _ := NormalizeMeasurement(measurement, sensor, time.Now()); ok {
		t.Fatal("expected unsupported metric to be skipped")
	}
}

func TestNormalizeMeasurementSkipsUnsupportedUnit(t *testing.T) {
	measurement := LatestMeasurement{SensorsID: 200}
	sensor := SensorMeta{ID: 200, Parameter: Parameter{Name: "no2"}, Units: "µg/m³"}

	if _, ok, _ := NormalizeMeasurement(measurement, sensor, time.Now()); ok {
		t.Fatal("expected unsupported unit to be skipped")
	}
}

func TestNormalizeMeasurementFallsBackToSensorCoordinates(t *testing.T) {
	lat, lon := 41.88, -87.63
	measurement := LatestMeasurement{
		DateTime:   DateTimeObject{UTC: time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)},
		Value:      0.04,
		SensorsID:  200,
		LocationID: 100,
	}
	sensor := SensorMeta{
		ID:          200,
		Parameter:   Parameter{Name: "o3"},
		Units:       "ppm",
		Coordinates: Coordinates{Latitude: &lat, Longitude: &lon},
	}

	reading, ok, reason := NormalizeMeasurement(measurement, sensor, measurement.DateTime.UTC)
	if !ok {
		t.Fatalf("expected reading, got skip reason %q", reason)
	}
	if reading.Latitude != lat || reading.Longitude != lon {
		t.Fatalf("expected sensor coordinates, got %+v", reading)
	}
}
