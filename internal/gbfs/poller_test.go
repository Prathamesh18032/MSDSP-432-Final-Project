package gbfs

import (
	"context"
	"testing"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type gbfsWriter struct {
	batch []readings.SensorReading
}

func (w *gbfsWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	w.batch = append(w.batch, batch...)
	return nil
}

func TestNewPollerRejectsNegativeLimit(t *testing.T) {
	client, err := NewClient(DefaultDiscoveryURL, "en", nil)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if _, err := NewPoller(client, &gbfsWriter{}, PollConfig{StationLimit: -1}, nil); err == nil {
		t.Fatal("expected negative limit error")
	}
}
