package usgs

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func NormalizeInstantaneous(response InstantaneousResponse, ingestedAt time.Time) ([]readings.SensorReading, []string) {
	out := make([]readings.SensorReading, 0)
	skipped := make([]string, 0)

	for _, series := range response.Value.TimeSeries {
		siteID := firstCode(series.SourceInfo.SiteCode)
		parameterCode := firstCode(series.Variable.VariableCode)
		metric, unit, ok := normalizeParameter(parameterCode, series.Variable.Unit.UnitCode)
		if !ok {
			skipped = append(skipped, fmt.Sprintf("unsupported USGS parameter/unit %s/%s", parameterCode, series.Variable.Unit.UnitCode))
			continue
		}
		if siteID == "" {
			skipped = append(skipped, "missing USGS site code")
			continue
		}

		for _, group := range series.Values {
			for _, measurement := range group.Value {
				if measurement.DateTime.IsZero() {
					skipped = append(skipped, fmt.Sprintf("missing USGS timestamp for site %s", siteID))
					continue
				}
				value, err := strconv.ParseFloat(strings.TrimSpace(measurement.Value), 64)
				if err != nil {
					skipped = append(skipped, fmt.Sprintf("invalid USGS value %q for site %s", measurement.Value, siteID))
					continue
				}

				out = append(out, readings.SensorReading{
					Time:          measurement.DateTime.UTC(),
					SensorID:      fmt.Sprintf("USGS-%s", siteID),
					Metric:        metric,
					Value:         value,
					Unit:          unit,
					Source:        readings.SourceUSGS,
					Latitude:      series.SourceInfo.GeoLocation.GeogLocation.Latitude,
					Longitude:     series.SourceInfo.GeoLocation.GeogLocation.Longitude,
					QualityFlag:   readings.QualityValid,
					IngestedAt:    ingestedAt.UTC(),
					SchemaVersion: readings.SchemaVersion,
				})
			}
		}
	}

	return out, skipped
}

func normalizeParameter(parameterCode, unitCode string) (string, string, bool) {
	switch strings.TrimSpace(parameterCode) {
	case "00065":
		if strings.EqualFold(strings.TrimSpace(unitCode), "ft") {
			return "water_gage_height", "ft", true
		}
	}
	return "", "", false
}

func firstCode(codes []Code) string {
	if len(codes) == 0 {
		return ""
	}
	return strings.TrimSpace(codes[0].Value)
}
