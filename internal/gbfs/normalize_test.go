package gbfs

import (
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func TestNormalizeStationsJoinsInformationAndStatus(t *testing.T) {
	var info StationInformationResponse
	info.Data.Stations = []StationInformation{
		{StationID: "a", Latitude: 41.88, Longitude: -87.62, Capacity: 20},
	}
	var status StationStatusResponse
	status.Data.Stations = []StationStatus{
		{StationID: "a", NumBikesAvailable: 7, NumDocksAvailable: 13, LastReported: 1779381000},
	}

	got, skipped := NormalizeStations(info, status, 25, time.Date(2026, 5, 21, 12, 0, 0, 0, time.UTC))
	if len(skipped) != 0 {
		t.Fatalf("unexpected skipped readings: %v", skipped)
	}
	if len(got) != 3 {
		t.Fatalf("readings = %d, want 3", len(got))
	}

	wantMetrics := map[string]float64{
		"bike_available_count": 7,
		"dock_available_count": 13,
		"station_capacity":     20,
	}
	for _, reading := range got {
		if reading.Source != readings.SourceGBFS {
			t.Fatalf("source = %q", reading.Source)
		}
		if reading.Unit != "count" {
			t.Fatalf("unit = %q", reading.Unit)
		}
		if wantMetrics[reading.Metric] != reading.Value {
			t.Fatalf("%s value = %f", reading.Metric, reading.Value)
		}
	}
}

func TestNormalizeStationsSkipsMissingInformation(t *testing.T) {
	var info StationInformationResponse
	var status StationStatusResponse
	status.Data.Stations = []StationStatus{{StationID: "missing"}}

	got, skipped := NormalizeStations(info, status, 25, time.Now())
	if len(got) != 0 {
		t.Fatalf("readings = %d, want 0", len(got))
	}
	if len(skipped) != 1 {
		t.Fatalf("skipped = %d, want 1", len(skipped))
	}
}

func TestNormalizeStationsAppliesLimitDeterministically(t *testing.T) {
	var info StationInformationResponse
	info.Data.Stations = []StationInformation{
		{StationID: "a", Capacity: 1},
		{StationID: "b", Capacity: 1},
	}
	var status StationStatusResponse
	status.Data.Stations = []StationStatus{{StationID: "b"}, {StationID: "a"}}

	got, skipped := NormalizeStations(info, status, 1, time.Now())
	if len(skipped) != 0 {
		t.Fatalf("unexpected skipped readings: %v", skipped)
	}
	if len(got) != 3 {
		t.Fatalf("readings = %d, want 3", len(got))
	}
	if got[0].SensorID != "GBFS-a" {
		t.Fatalf("first station = %q, want GBFS-a", got[0].SensorID)
	}
}
