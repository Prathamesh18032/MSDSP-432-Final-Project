package readings

import (
	"errors"
	"fmt"
	"math"
	"strings"
	"time"
)

const timestampSkew = 5 * time.Minute

var metricRanges = map[string]struct {
	min  float64
	max  float64
	unit string
}{
	"PM2.5":                {min: 0, max: 1000, unit: "ug/m3"},
	"O3":                   {min: 0, max: 1, unit: "ppm"},
	"NO2":                  {min: 0, max: 1000, unit: "ppb"},
	"temperature":          {min: -80, max: 60, unit: "C"},
	"humidity":             {min: 0, max: 100, unit: "%"},
	"wind_speed":           {min: 0, max: 400, unit: "km/h"},
	"precipitation":        {min: 0, max: 1000, unit: "mm"},
	"bike_available_count": {min: 0, max: 1000, unit: "count"},
	"dock_available_count": {min: 0, max: 1000, unit: "count"},
	"station_capacity":     {min: 0, max: 1000, unit: "count"},
	"water_gage_height":    {min: -100, max: 100, unit: "ft"},
}

func Validate(reading SensorReading, reference time.Time) error {
	var errs []error

	if reading.Time.IsZero() {
		errs = append(errs, errors.New("time is required"))
	} else {
		delta := reading.Time.UTC().Sub(reference.UTC())
		if delta > timestampSkew || delta < -timestampSkew {
			errs = append(errs, fmt.Errorf("time must be within %s of reference time", timestampSkew))
		}
	}

	if strings.TrimSpace(reading.SensorID) == "" {
		errs = append(errs, errors.New("sensor_id is required"))
	}
	if strings.TrimSpace(reading.Metric) == "" {
		errs = append(errs, errors.New("metric is required"))
	}
	if strings.TrimSpace(reading.Unit) == "" {
		errs = append(errs, errors.New("unit is required"))
	}
	if strings.TrimSpace(reading.Source) == "" {
		errs = append(errs, errors.New("source is required"))
	}
	if math.IsNaN(reading.Value) || math.IsInf(reading.Value, 0) {
		errs = append(errs, errors.New("value must be finite"))
	}
	if reading.Latitude < -90 || reading.Latitude > 90 {
		errs = append(errs, errors.New("latitude must be between -90 and 90"))
	}
	if reading.Longitude < -180 || reading.Longitude > 180 {
		errs = append(errs, errors.New("longitude must be between -180 and 180"))
	}
	if reading.SchemaVersion <= 0 {
		errs = append(errs, errors.New("schema_version must be positive"))
	}

	if rule, ok := metricRanges[reading.Metric]; ok {
		if reading.Value < rule.min || reading.Value > rule.max {
			errs = append(errs, fmt.Errorf("%s value must be between %.2f and %.2f", reading.Metric, rule.min, rule.max))
		}
		if reading.Unit != rule.unit {
			errs = append(errs, fmt.Errorf("%s unit must be %q", reading.Metric, rule.unit))
		}
	}

	return errors.Join(errs...)
}

func IsSupportedMetric(metric string) bool {
	_, ok := metricRanges[metric]
	return ok
}
