package openaq

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"testing"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

func jsonResponse(t *testing.T, payload any) *http.Response {
	t.Helper()

	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal response: %v", err)
	}
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(bytes.NewReader(body)),
		Header:     make(http.Header),
	}
}

func TestNewClientRequiresAPIKey(t *testing.T) {
	if _, err := NewClient(DefaultBaseURL, "", nil); err == nil {
		t.Fatal("expected missing API key error")
	}
}

func TestListLocationsSendsAPIKeyAndQuery(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/v3/locations" {
			t.Fatalf("path = %q, want /v3/locations", r.URL.Path)
		}
		if got := r.Header.Get("X-API-Key"); got != "test-key" {
			t.Fatalf("X-API-Key = %q, want test-key", got)
		}
		if got := r.URL.Query().Get("coordinates"); got != "41.8781,-87.6298" {
			t.Fatalf("coordinates = %q", got)
		}
		if got := r.URL.Query().Get("radius"); got != "25000" {
			t.Fatalf("radius = %q", got)
		}
		if got := r.URL.Query().Get("limit"); got != "5" {
			t.Fatalf("limit = %q", got)
		}
		return jsonResponse(t, map[string]any{
			"results": []map[string]any{{"id": 100, "name": "Chicago"}},
		}), nil
	})}

	client, err := NewClient("https://openaq.test", "test-key", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	locations, err := client.ListLocations(context.Background(), "41.8781,-87.6298", 25000, 5)
	if err != nil {
		t.Fatalf("ListLocations() error = %v", err)
	}
	if len(locations) != 1 || locations[0].ID != 100 {
		t.Fatalf("unexpected locations: %+v", locations)
	}
}

func TestListSensorsParsesSensorMetadata(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/v3/locations/100/sensors" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		return jsonResponse(t, map[string]any{
			"results": []map[string]any{
				{
					"id":        200,
					"name":      "PM2.5",
					"parameter": map[string]any{"id": 2, "name": "pm25", "units": "µg/m³"},
					"units":     nil,
				},
			},
		}), nil
	})}

	client, err := NewClient("https://openaq.test", "test-key", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	sensors, err := client.ListSensors(context.Background(), 100)
	if err != nil {
		t.Fatalf("ListSensors() error = %v", err)
	}
	if len(sensors) != 1 || sensors[0].ID != 200 || sensors[0].Parameter.Name != "pm25" || sensors[0].Parameter.Units != "µg/m³" {
		t.Fatalf("unexpected sensors: %+v", sensors)
	}
}

func TestLatestByLocationParsesMeasurements(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/v3/locations/100/latest" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		return jsonResponse(t, map[string]any{
			"results": []map[string]any{
				{
					"datetime": map[string]any{
						"utc":   "2026-05-20T12:00:00Z",
						"local": "2026-05-20T07:00:00-05:00",
					},
					"value":       12.3,
					"coordinates": map[string]any{"latitude": 41.88, "longitude": -87.63},
					"sensorsId":   200,
					"locationsId": 100,
				},
			},
		}), nil
	})}

	client, err := NewClient("https://openaq.test", "test-key", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	measurements, err := client.LatestByLocation(context.Background(), 100)
	if err != nil {
		t.Fatalf("LatestByLocation() error = %v", err)
	}
	if len(measurements) != 1 || measurements[0].SensorsID != 200 || measurements[0].Value != 12.3 {
		t.Fatalf("unexpected measurements: %+v", measurements)
	}
}
