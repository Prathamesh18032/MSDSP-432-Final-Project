package gbfs

import (
	"fmt"
	"sort"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func NormalizeStations(info StationInformationResponse, status StationStatusResponse, limit int, ingestedAt time.Time) ([]readings.SensorReading, []string) {
	infoByID := map[string]StationInformation{}
	for _, station := range info.Data.Stations {
		infoByID[station.StationID] = station
	}

	statuses := append([]StationStatus(nil), status.Data.Stations...)
	sort.Slice(statuses, func(i, j int) bool {
		return statuses[i].StationID < statuses[j].StationID
	})
	if limit > 0 && len(statuses) > limit {
		statuses = statuses[:limit]
	}

	out := make([]readings.SensorReading, 0, len(statuses)*3)
	skipped := make([]string, 0)
	for _, stationStatus := range statuses {
		stationInfo, ok := infoByID[stationStatus.StationID]
		if !ok {
			skipped = append(skipped, fmt.Sprintf("missing station_information for station %s", stationStatus.StationID))
			continue
		}

		observedAt := ingestedAt.UTC()
		if stationStatus.LastReported > 0 {
			observedAt = time.Unix(stationStatus.LastReported, 0).UTC()
		} else if status.LastUpdated > 0 {
			observedAt = time.Unix(status.LastUpdated, 0).UTC()
		}

		metrics := []struct {
			metric string
			value  int
		}{
			{metric: "bike_available_count", value: stationStatus.NumBikesAvailable},
			{metric: "dock_available_count", value: stationStatus.NumDocksAvailable},
			{metric: "station_capacity", value: stationInfo.Capacity},
		}

		for _, item := range metrics {
			out = append(out, readings.SensorReading{
				Time:          observedAt,
				SensorID:      fmt.Sprintf("GBFS-%s", stationStatus.StationID),
				Metric:        item.metric,
				Value:         float64(item.value),
				Unit:          "count",
				Source:        readings.SourceGBFS,
				Latitude:      stationInfo.Latitude,
				Longitude:     stationInfo.Longitude,
				QualityFlag:   readings.QualityValid,
				IngestedAt:    ingestedAt.UTC(),
				SchemaVersion: readings.SchemaVersion,
			})
		}
	}

	return out, skipped
}
