package gbfs

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestClientFetchStationsDiscoversAndParsesFeeds(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		switch r.URL.Path {
		case "/gbfs.json":
			return jsonResponse(`{"data":{"en":{"feeds":[{"name":"station_information","url":"https://gbfs.test/station_information.json"},{"name":"station_status","url":"https://gbfs.test/station_status.json"}]}}}`), nil
		case "/station_information.json":
			return jsonResponse(`{"last_updated":1779381000,"data":{"stations":[{"station_id":"a","name":"A","lat":41.88,"lon":-87.62,"capacity":20}]}}`), nil
		case "/station_status.json":
			return jsonResponse(`{"last_updated":1779381000,"data":{"stations":[{"station_id":"a","num_bikes_available":7,"num_docks_available":13,"last_reported":1779381000}]}}`), nil
		default:
			return nil, fmt.Errorf("unexpected path %s", r.URL.Path)
		}
	})}

	client, err := NewClient("https://gbfs.test/gbfs.json", "en", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	info, status, err := client.FetchStations(context.Background())
	if err != nil {
		t.Fatalf("FetchStations() error = %v", err)
	}
	if len(info.Data.Stations) != 1 || len(status.Data.Stations) != 1 {
		t.Fatalf("station counts = %d/%d", len(info.Data.Stations), len(status.Data.Stations))
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
