package openaq

import (
	"fmt"
	"strings"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func NormalizeMeasurement(measurement LatestMeasurement, sensor SensorMeta, ingestedAt time.Time) (readings.SensorReading, bool, string) {
	metric, wantUnit, ok := normalizeMetric(sensor.Parameter.Name)
	if !ok {
		return readings.SensorReading{}, false, fmt.Sprintf("unsupported OpenAQ parameter %q", sensor.Parameter.Name)
	}

	sourceUnit := sensor.Units
	if strings.TrimSpace(sourceUnit) == "" {
		sourceUnit = sensor.Parameter.Units
	}

	unit, ok := normalizeUnit(metric, sourceUnit)
	if !ok || unit != wantUnit {
		return readings.SensorReading{}, false, fmt.Sprintf("unsupported OpenAQ unit %q for %s", sourceUnit, metric)
	}

	latitude, longitude, ok := measurementCoordinates(measurement, sensor)
	if !ok {
		return readings.SensorReading{}, false, fmt.Sprintf("missing coordinates for OpenAQ sensor %d", measurement.SensorsID)
	}
	if measurement.DateTime.UTC.IsZero() {
		return readings.SensorReading{}, false, fmt.Sprintf("missing timestamp for OpenAQ sensor %d", measurement.SensorsID)
	}

	return readings.SensorReading{
		Time:          measurement.DateTime.UTC.UTC(),
		SensorID:      fmt.Sprintf("OPENAQ-%d", measurement.SensorsID),
		Metric:        metric,
		Value:         measurement.Value,
		Unit:          unit,
		Source:        readings.SourceOpenAQ,
		Latitude:      latitude,
		Longitude:     longitude,
		QualityFlag:   readings.QualityValid,
		IngestedAt:    ingestedAt.UTC(),
		SchemaVersion: readings.SchemaVersion,
	}, true, ""
}

func normalizeMetric(parameterName string) (metric string, unit string, ok bool) {
	key := strings.ToLower(strings.TrimSpace(parameterName))
	key = strings.NewReplacer(" ", "", "_", "", "-", "").Replace(key)

	switch key {
	case "pm25", "pm2.5":
		return "PM2.5", "ug/m3", true
	case "o3", "ozone":
		return "O3", "ppm", true
	case "no2", "nitrogendioxide":
		return "NO2", "ppb", true
	default:
		return "", "", false
	}
}

func normalizeUnit(metric, unit string) (string, bool) {
	cleaned := strings.ToLower(strings.TrimSpace(unit))
	cleaned = strings.NewReplacer(" ", "", "µ", "u", "μ", "u", "³", "3").Replace(cleaned)

	switch metric {
	case "PM2.5":
		if cleaned == "ug/m3" || cleaned == "ugm-3" || cleaned == "ugm3" {
			return "ug/m3", true
		}
	case "O3":
		if cleaned == "ppm" {
			return "ppm", true
		}
	case "NO2":
		if cleaned == "ppb" {
			return "ppb", true
		}
	}
	return "", false
}

func measurementCoordinates(measurement LatestMeasurement, sensor SensorMeta) (float64, float64, bool) {
	if measurement.Coordinates.Latitude != nil && measurement.Coordinates.Longitude != nil {
		return *measurement.Coordinates.Latitude, *measurement.Coordinates.Longitude, true
	}
	if sensor.Coordinates.Latitude != nil && sensor.Coordinates.Longitude != nil {
		return *sensor.Coordinates.Latitude, *sensor.Coordinates.Longitude, true
	}
	return 0, 0, false
}
