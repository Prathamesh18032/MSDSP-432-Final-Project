package openmeteo

import (
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func TestNormalizeCurrentMapsWeatherMetrics(t *testing.T) {
	response := CurrentResponse{
		Latitude:  41.8781,
		Longitude: -87.6298,
		CurrentUnits: CurrentUnits{
			Temperature2M:    "°C",
			RelativeHumidity: "%",
			WindSpeed10M:     "km/h",
			Precipitation:    "mm",
		},
		Current: CurrentWeather{
			Time:             "2026-05-21T15:30",
			Temperature2M:    21.4,
			RelativeHumidity: 54,
			WindSpeed10M:     18.1,
			Precipitation:    0.2,
		},
	}

	got, skipped := NormalizeCurrent(response, "OPENMETEO-CHI", time.Date(2026, 5, 21, 15, 31, 0, 0, time.UTC))
	if len(skipped) != 0 {
		t.Fatalf("unexpected skipped readings: %v", skipped)
	}
	if len(got) != 4 {
		t.Fatalf("readings = %d, want 4", len(got))
	}

	wantMetrics := map[string]string{
		"temperature":   "C",
		"humidity":      "%",
		"wind_speed":    "km/h",
		"precipitation": "mm",
	}
	for _, reading := range got {
		if reading.Source != readings.SourceOpenMeteo {
			t.Fatalf("source = %q", reading.Source)
		}
		if wantMetrics[reading.Metric] != reading.Unit {
			t.Fatalf("metric/unit = %s/%s", reading.Metric, reading.Unit)
		}
		if reading.Time.IsZero() {
			t.Fatal("expected timestamp")
		}
	}
}

func TestNormalizeCurrentSkipsUnsupportedUnit(t *testing.T) {
	response := CurrentResponse{
		Latitude:  41.8781,
		Longitude: -87.6298,
		CurrentUnits: CurrentUnits{
			Temperature2M:    "K",
			RelativeHumidity: "%",
			WindSpeed10M:     "km/h",
			Precipitation:    "mm",
		},
		Current: CurrentWeather{Time: "2026-05-21T15:30"},
	}

	got, skipped := NormalizeCurrent(response, "OPENMETEO-CHI", time.Now())
	if len(got) != 3 {
		t.Fatalf("readings = %d, want 3", len(got))
	}
	if len(skipped) != 1 {
		t.Fatalf("skipped = %d, want 1", len(skipped))
	}
}

func TestParseCoordinates(t *testing.T) {
	latitude, longitude, err := ParseCoordinates("41.8781,-87.6298")
	if err != nil {
		t.Fatalf("ParseCoordinates() error = %v", err)
	}
	if latitude != 41.8781 || longitude != -87.6298 {
		t.Fatalf("coordinates = %f,%f", latitude, longitude)
	}
}
