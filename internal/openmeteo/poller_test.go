package openmeteo

import (
	"context"
	"testing"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type openMeteoWriter struct {
	batch []readings.SensorReading
}

func (w *openMeteoWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	w.batch = append(w.batch, batch...)
	return nil
}

func TestNewPollerRejectsMissingCoordinates(t *testing.T) {
	client, err := NewClient(DefaultBaseURL, nil)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if _, err := NewPoller(client, &openMeteoWriter{}, PollConfig{}, nil); err == nil {
		t.Fatal("expected missing coordinates error")
	}
}
