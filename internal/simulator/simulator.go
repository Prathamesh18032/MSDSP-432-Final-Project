package simulator

import (
	"math"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type Sensor struct {
	ID        string
	Location  string
	Latitude  float64
	Longitude float64
}

type Simulator struct {
	sensors []Sensor
	metrics []metricProfile
}

type metricProfile struct {
	name      string
	unit      string
	baseline  float64
	amplitude float64
}

func New() Simulator {
	return Simulator{
		sensors: []Sensor{
			{ID: "SIM-CHI-AQ-001", Location: "Michigan Ave and Lake St", Latitude: 41.8864, Longitude: -87.6246},
			{ID: "SIM-CHI-AQ-002", Location: "West Loop", Latitude: 41.8840, Longitude: -87.6470},
			{ID: "SIM-CHI-AQ-003", Location: "Hyde Park", Latitude: 41.7943, Longitude: -87.5907},
		},
		metrics: []metricProfile{
			{name: "PM2.5", unit: "ug/m3", baseline: 8.5, amplitude: 3.2},
			{name: "O3", unit: "ppm", baseline: 0.035, amplitude: 0.012},
			{name: "NO2", unit: "ppb", baseline: 22.0, amplitude: 8.0},
			{name: "temperature", unit: "C", baseline: 19.0, amplitude: 7.0},
			{name: "humidity", unit: "%", baseline: 55.0, amplitude: 18.0},
		},
	}
}

func (s Simulator) Sensors() []Sensor {
	return append([]Sensor(nil), s.sensors...)
}

func (s Simulator) GenerateBatch(reference time.Time, samplesPerSensor int) []readings.SensorReading {
	if samplesPerSensor < 1 {
		samplesPerSensor = 1
	}

	base := reference.UTC().Truncate(time.Minute)
	result := make([]readings.SensorReading, 0, len(s.sensors)*len(s.metrics)*samplesPerSensor)

	for sample := 0; sample < samplesPerSensor; sample++ {
		ts := base.Add(time.Duration(sample) * time.Second)
		for sensorIndex, sensor := range s.sensors {
			for metricIndex, profile := range s.metrics {
				result = append(result, readings.SensorReading{
					Time:          ts,
					SensorID:      sensor.ID,
					Metric:        profile.name,
					Value:         deterministicValue(profile, sensorIndex, metricIndex, sample),
					Unit:          profile.unit,
					Source:        readings.SourceSimulator,
					Latitude:      sensor.Latitude,
					Longitude:     sensor.Longitude,
					QualityFlag:   readings.QualityValid,
					IngestedAt:    ts,
					SchemaVersion: readings.SchemaVersion,
				})
			}
		}
	}

	return result
}

func deterministicValue(profile metricProfile, sensorIndex, metricIndex, sample int) float64 {
	phase := float64(sensorIndex+1)*0.7 + float64(metricIndex+1)*0.3 + float64(sample)*0.2
	value := profile.baseline + profile.amplitude*math.Sin(phase)
	return math.Round(value*1000) / 1000
}
