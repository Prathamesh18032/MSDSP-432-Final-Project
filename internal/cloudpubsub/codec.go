package cloudpubsub

import (
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

const (
	AttributeSchemaVersion = "schema_version"
	AttributeSource        = "source"
	AttributeMetric        = "metric"
	AttributeSensorID      = "sensor_id"
	AttributeDedupKey      = "dedup_key"
)

func EncodeReading(reading readings.SensorReading) ([]byte, map[string]string, error) {
	data, err := json.Marshal(reading)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal sensor reading: %w", err)
	}

	attributes := map[string]string{
		AttributeSchemaVersion: strconv.Itoa(reading.SchemaVersion),
		AttributeSource:        reading.Source,
		AttributeMetric:        reading.Metric,
		AttributeSensorID:      reading.SensorID,
		AttributeDedupKey:      reading.DedupKey(),
	}

	return data, attributes, nil
}

func DecodeReading(data []byte) (readings.SensorReading, error) {
	var reading readings.SensorReading
	if err := json.Unmarshal(data, &reading); err != nil {
		return readings.SensorReading{}, fmt.Errorf("decode sensor reading: %w", err)
	}
	return reading, nil
}
