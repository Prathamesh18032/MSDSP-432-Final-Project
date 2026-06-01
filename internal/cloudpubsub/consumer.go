package cloudpubsub

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sync/atomic"
	"time"

	gcppubsub "cloud.google.com/go/pubsub"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/buffer"
	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type ReadingWriter interface {
	InsertReadings(ctx context.Context, batch []readings.SensorReading) error
}

type MetricsWriter interface {
	RecordIngestionMetrics(ctx context.Context, metric buffer.IngestionMetric) error
}

type Message struct {
	Data        []byte
	PublishTime time.Time
	Ack         func()
	Nack        func()
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
			Data:        message.Data,
			PublishTime: message.PublishTime,
			Ack:         message.Ack,
			Nack:        message.Nack,
		}, c.writer)
		if err != nil {
			c.logger.Printf("pubsub message failed: %v", err)
		}
	})
}

func (c *Consumer) ReceiveLimit(ctx context.Context, limit int) (int, error) {
	if limit <= 0 {
		return 0, fmt.Errorf("receive limit must be positive")
	}
	if c == nil || c.subscription == nil {
		return 0, errors.New("pubsub consumer is not initialized")
	}

	limitedCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	c.subscription.ReceiveSettings.MaxOutstandingMessages = 1
	c.subscription.ReceiveSettings.NumGoroutines = 1

	var acked int32
	err := c.subscription.Receive(limitedCtx, func(ctx context.Context, message *gcppubsub.Message) {
		if atomic.LoadInt32(&acked) >= int32(limit) {
			message.Nack()
			cancel()
			return
		}

		err := HandleMessage(ctx, Message{
			Data:        message.Data,
			PublishTime: message.PublishTime,
			Ack:         message.Ack,
			Nack:        message.Nack,
		}, c.writer)
		if err != nil {
			c.logger.Printf("pubsub message failed: %v", err)
			return
		}

		if atomic.AddInt32(&acked, 1) >= int32(limit) {
			cancel()
		}
	})

	count := int(atomic.LoadInt32(&acked))
	if errors.Is(err, context.Canceled) && count >= limit {
		return count, nil
	}
	return count, err
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

	if err := readings.Validate(reading, reading.Time); err != nil {
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

	if metrics, ok := writer.(MetricsWriter); ok {
		now := time.Now().UTC()
		var lagMillis *int
		if !message.PublishTime.IsZero() {
			lag := int(now.Sub(message.PublishTime).Milliseconds())
			if lag < 0 {
				lag = 0
			}
			lagMillis = &lag
		}
		_ = metrics.RecordIngestionMetrics(ctx, buffer.IngestionMetric{
			RecordedAt:           now,
			ReadingsPerSecond:    1,
			ChannelFillPct:       0,
			PubSubLagMillis:      lagMillis,
			DroppedReadingsTotal: 0,
		})
	}

	if message.Ack != nil {
		message.Ack()
	}
	return nil
}
