package cloudpubsub

import "testing"

func TestPublisherConfigValidation(t *testing.T) {
	valid := PublisherConfig{ProjectID: "project", TopicID: DefaultTopicID}
	if err := valid.Validate(); err != nil {
		t.Fatalf("Validate() error = %v", err)
	}

	if err := (PublisherConfig{TopicID: DefaultTopicID}).Validate(); err == nil {
		t.Fatal("expected missing project error")
	}
	if err := (PublisherConfig{ProjectID: "project"}).Validate(); err == nil {
		t.Fatal("expected missing topic error")
	}
}

func TestConsumerConfigValidation(t *testing.T) {
	valid := ConsumerConfig{ProjectID: "project", SubscriptionID: DefaultSubscriptionID, MaxMessages: 10}
	if err := valid.Validate(); err != nil {
		t.Fatalf("Validate() error = %v", err)
	}
	if valid.NormalizedMaxMessages() != 10 {
		t.Fatalf("NormalizedMaxMessages() = %d", valid.NormalizedMaxMessages())
	}

	defaulted := ConsumerConfig{ProjectID: "project", SubscriptionID: DefaultSubscriptionID}
	if defaulted.NormalizedMaxMessages() != DefaultMaxMessages {
		t.Fatalf("default max messages = %d", defaulted.NormalizedMaxMessages())
	}

	if err := (ConsumerConfig{SubscriptionID: DefaultSubscriptionID}).Validate(); err == nil {
		t.Fatal("expected missing project error")
	}
	if err := (ConsumerConfig{ProjectID: "project"}).Validate(); err == nil {
		t.Fatal("expected missing subscription error")
	}
	if err := (ConsumerConfig{ProjectID: "project", SubscriptionID: DefaultSubscriptionID, MaxMessages: -1}).Validate(); err == nil {
		t.Fatal("expected negative max messages error")
	}
}
