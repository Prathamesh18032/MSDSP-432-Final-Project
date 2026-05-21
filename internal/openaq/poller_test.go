package openaq

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type captureWriter struct {
	batch []readings.SensorReading
}

func (w *captureWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	w.batch = append(w.batch, batch...)
	return nil
}

func TestPollOnceHandlesEmptyLocations(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		return jsonResponse(t, map[string]any{"results": []any{}}), nil
	})}

	client, err := NewClient("https://openaq.test", "test-key", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}
	writer := &captureWriter{}
	poller, err := NewPoller(client, writer, PollConfig{Coordinates: "41.8781,-87.6298", RadiusMeters: 25000, LocationLimit: 5}, nil)
	if err != nil {
		t.Fatalf("NewPoller() error = %v", err)
	}

	stats, err := poller.PollOnce(context.Background())
	if err != nil {
		t.Fatalf("PollOnce() error = %v", err)
	}
	if stats.Locations != 0 || stats.Published != 0 || len(writer.batch) != 0 {
		t.Fatalf("unexpected stats/batch: %+v %#v", stats, writer.batch)
	}
}

func TestPollOnceNormalizesAndWritesSupportedMeasurements(t *testing.T) {
	lat, lon := 41.88, -87.63
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		switch r.URL.Path {
		case "/v3/locations":
			return jsonResponse(t, map[string]any{"results": []map[string]any{{"id": 100}}}), nil
		case "/v3/locations/100/sensors":
			return jsonResponse(t, map[string]any{
				"results": []map[string]any{
					{"id": 200, "parameter": map[string]any{"name": "pm25", "units": "µg/m³"}, "units": nil},
				},
			}), nil
		case "/v3/locations/100/latest":
			return jsonResponse(t, map[string]any{
				"results": []map[string]any{
					{
						"datetime": map[string]any{
							"utc":   "2026-05-20T12:00:00Z",
							"local": "2026-05-20T07:00:00-05:00",
						},
						"value":       12.3,
						"coordinates": map[string]any{"latitude": lat, "longitude": lon},
						"sensorsId":   200,
						"locationsId": 100,
					},
				},
			}), nil
		default:
			t.Fatalf("unexpected path %q", r.URL.Path)
			return nil, nil
		}
	})}

	client, err := NewClient("https://openaq.test", "test-key", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}
	writer := &captureWriter{}
	poller, err := NewPoller(client, writer, PollConfig{Coordinates: "41.8781,-87.6298", RadiusMeters: 25000, LocationLimit: 5}, nil)
	if err != nil {
		t.Fatalf("NewPoller() error = %v", err)
	}

	stats, err := poller.PollOnce(context.Background())
	if err != nil {
		t.Fatalf("PollOnce() error = %v", err)
	}
	if stats.Locations != 1 || stats.Measurements != 1 || stats.Published != 1 || stats.Skipped != 0 {
		t.Fatalf("unexpected stats: %+v", stats)
	}
	if len(writer.batch) != 1 || writer.batch[0].Metric != "PM2.5" || writer.batch[0].Time.IsZero() {
		t.Fatalf("unexpected batch: %+v", writer.batch)
	}
}

func TestNewPollerValidatesConfig(t *testing.T) {
	client, err := NewClient(DefaultBaseURL, "test-key", nil)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}
	writer := &captureWriter{}

	if _, err := NewPoller(client, writer, PollConfig{Coordinates: "", RadiusMeters: 25000, LocationLimit: 5}, nil); err == nil {
		t.Fatal("expected coordinates validation error")
	}
	if _, err := NewPoller(client, writer, PollConfig{Coordinates: "41.8781,-87.6298", RadiusMeters: 25001, LocationLimit: 5}, nil); err == nil {
		t.Fatal("expected radius validation error")
	}
	if _, err := NewPoller(client, writer, PollConfig{Coordinates: "41.8781,-87.6298", RadiusMeters: 25000, LocationLimit: 0}, nil); err == nil {
		t.Fatal("expected location limit validation error")
	}
}

func TestPollOnceSkipsUnsupportedMeasurements(t *testing.T) {
	measurementTime := time.Date(2026, 5, 20, 12, 0, 0, 0, time.UTC)
	lat, lon := 41.88, -87.63
	measurement := LatestMeasurement{
		DateTime:    DateTimeObject{UTC: measurementTime},
		Value:       20,
		Coordinates: Coordinates{Latitude: &lat, Longitude: &lon},
		SensorsID:   200,
	}
	sensor := SensorMeta{ID: 200, Parameter: Parameter{Name: "no2"}, Units: "µg/m³"}

	if _, ok, _ := NormalizeMeasurement(measurement, sensor, measurementTime); ok {
		t.Fatal("expected NO2 ug/m3 measurement to be skipped")
	}
}
