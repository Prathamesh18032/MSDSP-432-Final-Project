package cloudpubsub

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	gcppubsub "cloud.google.com/go/pubsub"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type ReadingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type Message struct {
	Data []byte
	Ack  func()
	Nack func()
}

type Consumer struct {
	client       *gcppubsub.Client
	subscription *gcppubsub.Subscription
	writer       ReadingWriter
	logger       *log.Logger
}

func NewConsumer(ctx context.Context, config ConsumerConfig, writer ReadingWriter, logger *log.Logger) (*Consumer, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}
	if writer == nil {
		return nil, errors.New("reading writer is required")
	}

	client, err := gcppubsub.NewClient(ctx, config.ProjectID)
	if err != nil {
		return nil, fmt.Errorf("create pubsub client: %w", err)
	}

	subscription := client.Subscription(config.SubscriptionID)
	subscription.ReceiveSettings.MaxOutstandingMessages = config.NormalizedMaxMessages()

	if logger == nil {
		logger = log.Default()
	}

	return &Consumer{
		client:       client,
		subscription: subscription,
		writer:       writer,
		logger:       logger,
	}, nil
}

func (c *Consumer) Receive(ctx context.Context) error {
	if c == nil || c.subscription == nil {
		return errors.New("pubsub consumer is not initialized")
	}

	return c.subscription.Receive(ctx, func(ctx context.Context, message *gcppubsub.Message) {
		err := HandleMessage(ctx, Message{
			Data: message.Data,
			Ack:  message.Ack,
			Nack: message.Nack,
		}, c.writer)
		if err != nil {
			c.logger.Printf("pubsub message failed: %v", err)
		}
	})
}

func (c *Consumer) Close() error {
	if c == nil || c.client == nil {
		return nil
	}
	return c.client.Close()
}

func HandleMessage(ctx context.Context, message Message, writer ReadingWriter) error {
	if writer == nil {
		if message.Nack != nil {
			message.Nack()
		}
		return errors.New("reading writer is required")
	}

	reading, err := DecodeReading(message.Data)
	if err != nil {
		if message.Nack != nil {
			message.Nack()
		}
		return err
	}

	reference := reading.IngestedAt
	if reference.IsZero() {
		reference = time.Now().UTC()
	}
	if err := readings.Validate(reading, reference); err != nil {
		if message.Nack != nil {
			message.Nack()
		}
		return fmt.Errorf("validate pubsub reading %s: %w", reading.DedupKey(), err)
	}

	if err := writer.InsertReadings(ctx, []readings.SensorReading{reading}); err != nil {
		if message.Nack != nil {
			message.Nack()
		}
		return fmt.Errorf("write pubsub reading %s: %w", reading.DedupKey(), err)
	}

	if message.Ack != nil {
		message.Ack()
	}
	return nil
}
