package cloudpubsub

import (
	"context"
	"errors"
	"testing"

	gcppubsub "cloud.google.com/go/pubsub"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type fakePublishResult struct {
	err error
}

func (r fakePublishResult) Get(context.Context) (string, error) {
	if r.err != nil {
		return "", r.err
	}
	return "server-id", nil
}

func TestPublisherInsertReadingsPublishesMessages(t *testing.T) {
	var published []*gcppubsub.Message
	publisher := newPublisherForTest(func(_ context.Context, message *gcppubsub.Message) publishResult {
		published = append(published, message)
		return fakePublishResult{}
	})

	if err := publisher.InsertReadings(context.Background(), []readings.SensorReading{testReading()}); err != nil {
		t.Fatalf("InsertReadings() error = %v", err)
	}

	if len(published) != 1 {
		t.Fatalf("published messages = %d, want 1", len(published))
	}
	if published[0].Attributes[AttributeDedupKey] != testReading().DedupKey() {
		t.Fatalf("dedup key attribute = %q", published[0].Attributes[AttributeDedupKey])
	}
}

func TestPublisherInsertReadingsEmptyBatchDoesNotPublish(t *testing.T) {
	called := false
	publisher := newPublisherForTest(func(_ context.Context, _ *gcppubsub.Message) publishResult {
		called = true
		return fakePublishResult{}
	})

	if err := publisher.InsertReadings(context.Background(), nil); err != nil {
		t.Fatalf("InsertReadings() error = %v", err)
	}
	if called {
		t.Fatal("publish was called for empty batch")
	}
}

func TestPublisherInsertReadingsReturnsPublishErrors(t *testing.T) {
	publisher := newPublisherForTest(func(_ context.Context, _ *gcppubsub.Message) publishResult {
		return fakePublishResult{err: errors.New("publish failed")}
	})

	if err := publisher.InsertReadings(context.Background(), []readings.SensorReading{testReading()}); err == nil {
		t.Fatal("expected publish error")
	}
}
