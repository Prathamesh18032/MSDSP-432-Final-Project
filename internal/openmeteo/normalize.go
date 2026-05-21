package openmeteo

import (
	"fmt"
	"strings"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func NormalizeCurrent(response CurrentResponse, sensorID string, ingestedAt time.Time) ([]readings.SensorReading, []string) {
	observedAt, err := parseOpenMeteoTime(response.Current.Time)
	if err != nil {
		return nil, []string{fmt.Sprintf("invalid Open-Meteo timestamp %q: %v", response.Current.Time, err)}
	}

	metrics := []struct {
		metric string
		value  float64
		unit   string
	}{
		{metric: "temperature", value: response.Current.Temperature2M, unit: normalizeUnit(response.CurrentUnits.Temperature2M)},
		{metric: "humidity", value: response.Current.RelativeHumidity, unit: normalizeUnit(response.CurrentUnits.RelativeHumidity)},
		{metric: "wind_speed", value: response.Current.WindSpeed10M, unit: normalizeUnit(response.CurrentUnits.WindSpeed10M)},
		{metric: "precipitation", value: response.Current.Precipitation, unit: normalizeUnit(response.CurrentUnits.Precipitation)},
	}

	readingsOut := make([]readings.SensorReading, 0, len(metrics))
	skipped := make([]string, 0)
	for _, item := range metrics {
		if item.unit == "" {
			skipped = append(skipped, fmt.Sprintf("unsupported Open-Meteo unit for %s", item.metric))
			continue
		}
		readingsOut = append(readingsOut, readings.SensorReading{
			Time:          observedAt,
			SensorID:      sensorID,
			Metric:        item.metric,
			Value:         item.value,
			Unit:          item.unit,
			Source:        readings.SourceOpenMeteo,
			Latitude:      response.Latitude,
			Longitude:     response.Longitude,
			QualityFlag:   readings.QualityValid,
			IngestedAt:    ingestedAt.UTC(),
			SchemaVersion: readings.SchemaVersion,
		})
	}
	return readingsOut, skipped
}

func parseOpenMeteoTime(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, fmt.Errorf("time is required")
	}
	if parsed, err := time.Parse(time.RFC3339, value); err == nil {
		return parsed.UTC(), nil
	}
	parsed, err := time.ParseInLocation("2006-01-02T15:04", value, time.UTC)
	if err != nil {
		return time.Time{}, err
	}
	return parsed.UTC(), nil
}

func normalizeUnit(unit string) string {
	switch strings.TrimSpace(unit) {
	case "°C":
		return "C"
	case "%":
		return "%"
	case "km/h":
		return "km/h"
	case "mm":
		return "mm"
	default:
		return ""
	}
}
