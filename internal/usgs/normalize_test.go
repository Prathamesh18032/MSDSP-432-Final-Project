package usgs

import (
	"testing"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func TestNormalizeInstantaneousMapsGageHeight(t *testing.T) {
	var response InstantaneousResponse
	response.Value.TimeSeries = []TimeSeries{
		{
			SourceInfo: SourceInfo{
				SiteCode: []Code{{Value: "05536123"}},
				GeoLocation: GeoLocation{GeogLocation: GeogLocation{
					Latitude:  41.887,
					Longitude: -87.620,
				}},
			},
			Variable: Variable{
				VariableCode: []Code{{Value: "00065"}},
				Unit:         Unit{UnitCode: "ft"},
			},
			Values: []Values{{Value: []MeasurementValue{{
				Value:    "2.71",
				DateTime: time.Date(2026, 5, 21, 12, 0, 0, 0, time.UTC),
			}}}},
		},
	}

	got, skipped := NormalizeInstantaneous(response, time.Date(2026, 5, 21, 12, 1, 0, 0, time.UTC))
	if len(skipped) != 0 {
		t.Fatalf("unexpected skipped readings: %v", skipped)
	}
	if len(got) != 1 {
		t.Fatalf("readings = %d, want 1", len(got))
	}
	reading := got[0]
	if reading.Source != readings.SourceUSGS {
		t.Fatalf("source = %q", reading.Source)
	}
	if reading.Metric != "water_gage_height" || reading.Unit != "ft" || reading.Value != 2.71 {
		t.Fatalf("reading = %s/%s/%f", reading.Metric, reading.Unit, reading.Value)
	}
}

func TestNormalizeInstantaneousSkipsUnsupportedParameter(t *testing.T) {
	var response InstantaneousResponse
	response.Value.TimeSeries = []TimeSeries{
		{
			SourceInfo: SourceInfo{SiteCode: []Code{{Value: "05536123"}}},
			Variable:   Variable{VariableCode: []Code{{Value: "00060"}}, Unit: Unit{UnitCode: "ft3/s"}},
		},
	}

	got, skipped := NormalizeInstantaneous(response, time.Now())
	if len(got) != 0 {
		t.Fatalf("readings = %d, want 0", len(got))
	}
	if len(skipped) != 1 {
		t.Fatalf("skipped = %d, want 1", len(skipped))
	}
}

func TestNormalizeInstantaneousSkipsInvalidValue(t *testing.T) {
	var response InstantaneousResponse
	response.Value.TimeSeries = []TimeSeries{
		{
			SourceInfo: SourceInfo{SiteCode: []Code{{Value: "05536123"}}},
			Variable:   Variable{VariableCode: []Code{{Value: "00065"}}, Unit: Unit{UnitCode: "ft"}},
			Values:     []Values{{Value: []MeasurementValue{{Value: "Ice", DateTime: time.Now()}}}},
		},
	}

	got, skipped := NormalizeInstantaneous(response, time.Now())
	if len(got) != 0 {
		t.Fatalf("readings = %d, want 0", len(got))
	}
	if len(skipped) != 1 {
		t.Fatalf("skipped = %d, want 1", len(skipped))
	}
}
