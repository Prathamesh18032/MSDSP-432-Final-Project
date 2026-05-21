package coldstore

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet/file"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

func TestPartitionPath(t *testing.T) {
	reading := testReading(time.Date(2026, 5, 21, 6, 30, 0, 0, time.UTC))

	got := PartitionPath(reading)
	want := filepath.Join("source=simulator", "metric=PM2.5", "year=2026", "month=05", "day=21")
	if got != want {
		t.Fatalf("PartitionPath() = %q, want %q", got, want)
	}
}

func TestSensorReadingSchema(t *testing.T) {
	schema := SensorReadingSchema()
	want := []string{
		"time",
		"sensor_id",
		"metric",
		"value",
		"unit",
		"source",
		"latitude",
		"longitude",
		"quality_flag",
		"ingested_at",
		"schema_version",
	}

	if schema.NumFields() != len(want) {
		t.Fatalf("schema.NumFields() = %d, want %d", schema.NumFields(), len(want))
	}
	for idx, name := range want {
		if got := schema.Field(idx).Name; got != name {
			t.Fatalf("schema field %d = %q, want %q", idx, got, name)
		}
	}
}

func TestWriteSensorReadingsEmptyBatch(t *testing.T) {
	dir := t.TempDir()
	results, err := WriteSensorReadings(dir, nil, time.Now())
	if err != nil {
		t.Fatalf("WriteSensorReadings() error = %v", err)
	}
	if len(results) != 0 {
		t.Fatalf("len(results) = %d, want 0", len(results))
	}
	if _, err := os.Stat(filepath.Join(dir, "sensor_readings")); !os.IsNotExist(err) {
		t.Fatalf("expected no sensor_readings directory, stat error = %v", err)
	}
}

func TestWriteSensorReadingsCreatesReadableParquet(t *testing.T) {
	dir := t.TempDir()
	exportTime := time.Date(2026, 5, 21, 7, 0, 0, 0, time.UTC)

	results, err := WriteSensorReadings(dir, []readings.SensorReading{
		testReading(time.Date(2026, 5, 21, 6, 30, 0, 0, time.UTC)),
	}, exportTime)
	if err != nil {
		t.Fatalf("WriteSensorReadings() error = %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("len(results) = %d, want 1", len(results))
	}
	if results[0].Rows != 1 {
		t.Fatalf("results[0].Rows = %d, want 1", results[0].Rows)
	}
	if filepath.Ext(results[0].Path) != ".parquet" {
		t.Fatalf("expected parquet file path, got %q", results[0].Path)
	}

	handle, err := os.Open(results[0].Path)
	if err != nil {
		t.Fatalf("open parquet file: %v", err)
	}
	defer handle.Close()

	reader, err := file.NewParquetReader(handle)
	if err != nil {
		t.Fatalf("NewParquetReader() error = %v", err)
	}
	defer reader.Close()

	arrowReader, err := pqarrow.NewFileReader(reader, pqarrow.ArrowReadProperties{BatchSize: 100}, memory.DefaultAllocator)
	if err != nil {
		t.Fatalf("NewFileReader() error = %v", err)
	}
	schema, err := arrowReader.Schema()
	if err != nil {
		t.Fatalf("Schema() error = %v", err)
	}
	if schema.NumFields() != SensorReadingSchema().NumFields() {
		t.Fatalf("schema.NumFields() = %d, want %d", schema.NumFields(), SensorReadingSchema().NumFields())
	}
	if reader.NumRows() != 1 {
		t.Fatalf("reader.NumRows() = %d, want 1", reader.NumRows())
	}
}

func testReading(timestamp time.Time) readings.SensorReading {
	return readings.SensorReading{
		Time:          timestamp,
		SensorID:      "sim-chicago-loop-01",
		Metric:        "PM2.5",
		Value:         12.5,
		Unit:          "ug/m3",
		Source:        readings.SourceSimulator,
		Latitude:      41.8781,
		Longitude:     -87.6298,
		QualityFlag:   readings.QualityValid,
		IngestedAt:    timestamp.Add(time.Second),
		SchemaVersion: readings.SchemaVersion,
	}
}
