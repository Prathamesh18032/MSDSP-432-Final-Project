package cloudpubsub

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/buffer"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type captureWriter struct {
	batch   []readings.SensorReading
	metrics []buffer.IngestionMetric
	err     error
}

func (w *captureWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	w.batch = append(w.batch, batch...)
	return w.err
}

func (w *captureWriter) RecordIngestionMetrics(_ context.Context, metric buffer.IngestionMetric) error {
	w.metrics = append(w.metrics, metric)
	return nil
}

func TestHandleMessageAcksAfterSuccessfulWrite(t *testing.T) {
	reading := testReading()
	data, _, err := EncodeReading(reading)
	if err != nil {
		t.Fatalf("EncodeReading() error = %v", err)
	}

	acks := 0
	nacks := 0
	writer := &captureWriter{}
	err = HandleMessage(context.Background(), Message{
		Data: data,
		Ack:  func() { acks++ },
		Nack: func() { nacks++ },
	}, writer)
	if err != nil {
		t.Fatalf("HandleMessage() error = %v", err)
	}
	if acks != 1 || nacks != 0 {
		t.Fatalf("acks=%d nacks=%d", acks, nacks)
	}
	if len(writer.batch) != 1 || writer.batch[0].DedupKey() != reading.DedupKey() {
		t.Fatalf("writer batch = %+v", writer.batch)
	}
	if len(writer.metrics) != 1 {
		t.Fatalf("metrics count = %d, want 1", len(writer.metrics))
	}
	if writer.metrics[0].ReadingsPerSecond != 1 || writer.metrics[0].ChannelFillPct != 0 {
		t.Fatalf("unexpected metrics: %+v", writer.metrics[0])
	}
}

func TestHandleMessageRecordsPubSubLag(t *testing.T) {
	reading := testReading()
	data, _, err := EncodeReading(reading)
	if err != nil {
		t.Fatalf("EncodeReading() error = %v", err)
	}

	writer := &captureWriter{}
	err = HandleMessage(context.Background(), Message{
		Data:        data,
		PublishTime: time.Now().Add(-2 * time.Second),
		Ack:         func() {},
	}, writer)
	if err != nil {
		t.Fatalf("HandleMessage() error = %v", err)
	}
	if len(writer.metrics) != 1 {
		t.Fatalf("metrics count = %d, want 1", len(writer.metrics))
	}
	if writer.metrics[0].PubSubLagMillis == nil || *writer.metrics[0].PubSubLagMillis <= 0 {
		t.Fatalf("expected positive pubsub lag, got %+v", writer.metrics[0])
	}
}

func TestHandleMessageNacksInvalidJSON(t *testing.T) {
	acks := 0
	nacks := 0
	err := HandleMessage(context.Background(), Message{
		Data: []byte("{"),
		Ack:  func() { acks++ },
		Nack: func() { nacks++ },
	}, &captureWriter{})
	if err == nil {
		t.Fatal("expected invalid JSON error")
	}
	if acks != 0 || nacks != 1 {
		t.Fatalf("acks=%d nacks=%d", acks, nacks)
	}
}

func TestHandleMessageNacksInvalidReading(t *testing.T) {
	reading := testReading()
	reading.SensorID = ""
	data, _, err := EncodeReading(reading)
	if err != nil {
		t.Fatalf("EncodeReading() error = %v", err)
	}

	nacks := 0
	err = HandleMessage(context.Background(), Message{
		Data: data,
		Nack: func() { nacks++ },
	}, &captureWriter{})
	if err == nil {
		t.Fatal("expected validation error")
	}
	if nacks != 1 {
		t.Fatalf("nacks=%d", nacks)
	}
}

func TestHandleMessageNacksWriteFailure(t *testing.T) {
	data, _, err := EncodeReading(testReading())
	if err != nil {
		t.Fatalf("EncodeReading() error = %v", err)
	}

	nacks := 0
	err = HandleMessage(context.Background(), Message{
		Data: data,
		Nack: func() { nacks++ },
	}, &captureWriter{err: errors.New("db failed")})
	if err == nil {
		t.Fatal("expected write error")
	}
	if nacks != 1 {
		t.Fatalf("nacks=%d", nacks)
	}
}

func TestHandleMessageAcceptsDelayedButValidReading(t *testing.T) {
	reading := testReading()
	reading.Time = time.Date(2026, 5, 24, 12, 0, 0, 0, time.UTC)
	reading.IngestedAt = reading.Time.Add(2 * time.Hour)
	data, _, err := EncodeReading(reading)
	if err != nil {
		t.Fatalf("EncodeReading() error = %v", err)
	}

	acks := 0
	writer := &captureWriter{}
	err = HandleMessage(context.Background(), Message{
		Data: data,
		Ack:  func() { acks++ },
	}, writer)
	if err != nil {
		t.Fatalf("HandleMessage() error = %v", err)
	}
	if acks != 1 {
		t.Fatalf("acks=%d", acks)
	}
}
