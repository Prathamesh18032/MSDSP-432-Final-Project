package usgs

import (
	"context"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestClientInstantaneousValuesParsesResponse(t *testing.T) {
	httpClient := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path != "/nwis/iv/" {
			t.Fatalf("path = %q", r.URL.Path)
		}
		if r.URL.Query().Get("sites") != "05536123" {
			t.Fatalf("sites = %q", r.URL.Query().Get("sites"))
		}
		return jsonResponse(`{
			"value":{"timeSeries":[{
				"sourceInfo":{"siteName":"Chicago River","siteCode":[{"value":"05536123"}],"geoLocation":{"geogLocation":{"latitude":41.887,"longitude":-87.62}}},
				"variable":{"variableCode":[{"value":"00065"}],"variableName":"Gage height","unit":{"unitCode":"ft"}},
				"values":[{"value":[{"value":"2.71","dateTime":"2026-05-21T12:00:00.000Z"}]}]
			}]}
		}`), nil
	})}

	client, err := NewClient("https://usgs.test", httpClient)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	got, err := client.InstantaneousValues(context.Background(), "05536123", "00065")
	if err != nil {
		t.Fatalf("InstantaneousValues() error = %v", err)
	}
	if len(got.Value.TimeSeries) != 1 {
		t.Fatalf("time series = %d, want 1", len(got.Value.TimeSeries))
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
