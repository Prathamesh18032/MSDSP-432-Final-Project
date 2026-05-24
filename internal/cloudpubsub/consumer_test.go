package cloudpubsub

import (
	"context"
	"errors"
	"testing"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type captureWriter struct {
	batch []readings.SensorReading
	err   error
}

func (w *captureWriter) InsertReadings(_ context.Context, batch []readings.SensorReading) error {
	w.batch = append(w.batch, batch...)
	return w.err
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
