package openmeteo

import (
	"context"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestClientCurrentParsesResponse(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/v1/forecast" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		if r.URL.Query().Get("timezone") != "UTC" {
			t.Fatalf("timezone = %q", r.URL.Query().Get("timezone"))
		}
		return jsonResponse(`{
			"latitude":41.8781,
			"longitude":-87.6298,
			"current_units":{"time":"iso8601","temperature_2m":"°C","relative_humidity_2m":"%","wind_speed_10m":"km/h","precipitation":"mm"},
			"current":{"time":"2026-05-21T15:30","temperature_2m":21.4,"relative_humidity_2m":54,"wind_speed_10m":18.1,"precipitation":0.2}
		}`), nil
	})}

	client, err := NewClient("https://openmeteo.test", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	got, err := client.Current(context.Background(), 41.8781, -87.6298)
	if err != nil {
		t.Fatalf("Current() error = %v", err)
	}
	if got.Current.Temperature2M != 21.4 {
		t.Fatalf("temperature = %f", got.Current.Temperature2M)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return fn(req)
}

func jsonResponse(body string) *http.Response {
	return &http.Response{
		StatusCode: http.StatusOK,
		Header:     http.Header{"Content-Type": []string{"application/json"}},
		Body:       io.NopCloser(strings.NewReader(body)),
	}
}
