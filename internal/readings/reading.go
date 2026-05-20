package readings

import "time"

const (
	SourceSimulator = "simulator"

	QualityInvalid = -1
	QualitySuspect = 0
	QualityValid   = 1

	SchemaVersion = 1
)

// SensorReading is the shared contract that flows from ingestion to storage.
type SensorReading struct {
	Time          time.Time `json:"time"`
	SensorID      string    `json:"sensor_id"`
	Metric        string    `json:"metric"`
	Value         float64   `json:"value"`
	Unit          string    `json:"unit"`
	Source        string    `json:"source"`
	Latitude      float64   `json:"latitude"`
	Longitude     float64   `json:"longitude"`
	QualityFlag   int16     `json:"quality_flag"`
	IngestedAt    time.Time `json:"ingested_at"`
	SchemaVersion int       `json:"schema_version"`
}

func (r SensorReading) DedupKey() string {
	return r.SensorID + "|" + r.Time.UTC().Format(time.RFC3339Nano) + "|" + r.Metric
}
