package cloudpubsub

import (
	"context"
	"errors"
	"fmt"

	gcppubsub "cloud.google.com/go/pubsub"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type publishResult interface {
	Get(context.Context) (string, error)
}

type publishFunc func(context.Context, *gcppubsub.Message) publishResult

type Publisher struct {
	publish publishFunc
	close   func() error
}

func NewPublisher(ctx context.Context, config PublisherConfig) (*Publisher, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	client, err := gcppubsub.NewClient(ctx, config.ProjectID)
	if err != nil {
		return nil, fmt.Errorf("create pubsub client: %w", err)
	}

	topic := client.Topic(config.TopicID)
	return &Publisher{
		publish: func(ctx context.Context, message *gcppubsub.Message) publishResult {
			return topic.Publish(ctx, message)
		},
		close: func() error {
			topic.Stop()
			return client.Close()
		},
	}, nil
}

func newPublisherForTest(publish publishFunc) *Publisher {
	return &Publisher{publish: publish, close: func() error { return nil }}
}

func (p *Publisher) InsertReadings(ctx context.Context, batch []readings.SensorReading) error {
	if len(batch) == 0 {
		return nil
	}
	if p == nil || p.publish == nil {
		return errors.New("pubsub publisher is not initialized")
	}

	results := make([]publishResult, 0, len(batch))
	for _, reading := range batch {
		data, attributes, err := EncodeReading(reading)
		if err != nil {
			return err
		}
		results = append(results, p.publish(ctx, &gcppubsub.Message{
			Data:       data,
			Attributes: attributes,
		}))
	}

	var errs []error
	for index, result := range results {
		if result == nil {
			errs = append(errs, fmt.Errorf("publish reading %d: missing publish result", index))
			continue
		}
		if _, err := result.Get(ctx); err != nil {
			errs = append(errs, fmt.Errorf("publish reading %d: %w", index, err))
		}
	}
	return errors.Join(errs...)
}

func (p *Publisher) Close() error {
	if p == nil || p.close == nil {
		return nil
	}
	return p.close()
}
