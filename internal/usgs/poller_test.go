package usgs

import (
	"context"
	"testing"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type usgsWriter struct {
	batch []readings.SensorReading
}

func (w *usgsWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	w.batch = append(w.batch, batch...)
	return nil
}

func TestNewPollerRejectsMissingSiteIDs(t *testing.T) {
	client, err := NewClient(DefaultBaseURL, nil)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if _, err := NewPoller(client, &usgsWriter{}, PollConfig{ParameterCodes: "00065"}, nil); err == nil {
		t.Fatal("expected missing site IDs error")
	}
}
