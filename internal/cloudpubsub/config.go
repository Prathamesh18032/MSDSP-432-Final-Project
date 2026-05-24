package cloudpubsub

import (
	"errors"
	"fmt"
	"strings"
)

const (
	DefaultTopicID        = "smartcity-readings"
	DefaultSubscriptionID = "smartcity-hot-writer"
	DefaultMaxMessages    = 100
)

type PublisherConfig struct {
	ProjectID string
	TopicID   string
}

func (c PublisherConfig) Validate() error {
	var errs []error
	if strings.TrimSpace(c.ProjectID) == "" {
		errs = append(errs, errors.New("GCP_PROJECT_ID is required"))
	}
	if strings.TrimSpace(c.TopicID) == "" {
		errs = append(errs, errors.New("GCP_PUBSUB_TOPIC is required"))
	}
	return errors.Join(errs...)
}

type ConsumerConfig struct {
	ProjectID      string
	SubscriptionID string
	MaxMessages    int
}

func (c ConsumerConfig) Validate() error {
	var errs []error
	if strings.TrimSpace(c.ProjectID) == "" {
		errs = append(errs, errors.New("GCP_PROJECT_ID is required"))
	}
	if strings.TrimSpace(c.SubscriptionID) == "" {
		errs = append(errs, errors.New("GCP_PUBSUB_SUBSCRIPTION is required"))
	}
	if c.MaxMessages < 0 {
		errs = append(errs, fmt.Errorf("PUBSUB_MAX_MESSAGES cannot be negative"))
	}
	return errors.Join(errs...)
}

func (c ConsumerConfig) NormalizedMaxMessages() int {
	if c.MaxMessages == 0 {
		return DefaultMaxMessages
	}
	return c.MaxMessages
}
