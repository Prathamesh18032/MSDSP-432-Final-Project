package coldstore

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type FileResult struct {
	Path string
	Rows int
}

type UploadResult struct {
	LocalPath string
	Object    string
	URI       string
	Rows      int
}

var partitionSafePattern = regexp.MustCompile(`[^A-Za-z0-9._-]+`)

func SensorReadingSchema() *arrow.Schema {
	return arrow.NewSchema([]arrow.Field{
		{Name: "time", Type: arrow.FixedWidthTypes.Timestamp_us, Nullable: false},
		{Name: "sensor_id", Type: arrow.BinaryTypes.String, Nullable: false},
		{Name: "metric", Type: arrow.BinaryTypes.String, Nullable: false},
		{Name: "value", Type: arrow.PrimitiveTypes.Float64, Nullable: false},
		{Name: "unit", Type: arrow.BinaryTypes.String, Nullable: false},
		{Name: "source", Type: arrow.BinaryTypes.String, Nullable: false},
		{Name: "latitude", Type: arrow.PrimitiveTypes.Float64, Nullable: false},
		{Name: "longitude", Type: arrow.PrimitiveTypes.Float64, Nullable: false},
		{Name: "quality_flag", Type: arrow.PrimitiveTypes.Int16, Nullable: false},
		{Name: "ingested_at", Type: arrow.FixedWidthTypes.Timestamp_us, Nullable: false},
		{Name: "schema_version", Type: arrow.PrimitiveTypes.Int32, Nullable: false},
	}, nil)
}

func WriteSensorReadings(root string, batch []readings.SensorReading, exportTime time.Time) ([]FileResult, error) {
	if root == "" {
		return nil, fmt.Errorf("cold storage root is required")
	}
	if len(batch) == 0 {
		return nil, nil
	}

	groups := groupByPartition(batch)
	keys := make([]string, 0, len(groups))
	for key := range groups {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	results := make([]FileResult, 0, len(keys))
	for _, key := range keys {
		group := groups[key]
		if len(group) == 0 {
			continue
		}

		outputDir := filepath.Join(root, "sensor_readings", key)
		if err := os.MkdirAll(outputDir, 0o755); err != nil {
			return nil, fmt.Errorf("create cold partition %s: %w", outputDir, err)
		}

		outputPath := filepath.Join(outputDir, fmt.Sprintf("part-%s.parquet", exportTime.UTC().Format("20060102T150405.000000Z")))
		if err := writeParquetFile(outputPath, group); err != nil {
			return nil, err
		}

		results = append(results, FileResult{Path: outputPath, Rows: len(group)})
	}

	return results, nil
}

func PartitionPath(reading readings.SensorReading) string {
	timestamp := reading.Time.UTC()
	return filepath.Join(
		"source="+partitionValue(reading.Source),
		"metric="+partitionValue(reading.Metric),
		fmt.Sprintf("year=%04d", timestamp.Year()),
		fmt.Sprintf("month=%02d", int(timestamp.Month())),
		fmt.Sprintf("day=%02d", timestamp.Day()),
	)
}

func GCSObjectName(root string, localPath string) (string, error) {
	if root == "" {
		return "", fmt.Errorf("cold storage root is required")
	}
	if localPath == "" {
		return "", fmt.Errorf("local path is required")
	}

	relative, err := filepath.Rel(root, localPath)
	if err != nil {
		return "", fmt.Errorf("calculate GCS object name: %w", err)
	}
	if relative == "." || relative == "" || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("local path %q must be inside cold storage root %q", localPath, root)
	}
	return filepath.ToSlash(relative), nil
}

func UploadSensorReadingFiles(ctx context.Context, root string, bucketName string, files []FileResult) ([]UploadResult, error) {
	if bucketName == "" {
		return nil, fmt.Errorf("GCS bucket is required")
	}
	if len(files) == 0 {
		return nil, nil
	}

	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("create GCS client: %w", err)
	}
	defer client.Close()

	bucket := client.Bucket(bucketName)
	results := make([]UploadResult, 0, len(files))
	for _, file := range files {
		objectName, err := GCSObjectName(root, file.Path)
		if err != nil {
			return nil, err
		}
		if err := uploadFile(ctx, bucket, objectName, file.Path); err != nil {
			return nil, err
		}
		results = append(results, UploadResult{
			LocalPath: file.Path,
			Object:    objectName,
			URI:       fmt.Sprintf("gs://%s/%s", bucketName, objectName),
			Rows:      file.Rows,
		})
	}
	return results, nil
}

func groupByPartition(batch []readings.SensorReading) map[string][]readings.SensorReading {
	groups := make(map[string][]readings.SensorReading)
	for _, reading := range batch {
		key := PartitionPath(reading)
		groups[key] = append(groups[key], reading)
	}
	return groups
}

func uploadFile(ctx context.Context, bucket *storage.BucketHandle, objectName string, localPath string) error {
	source, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("open local Parquet file %s: %w", localPath, err)
	}
	defer source.Close()

	writer := bucket.Object(objectName).NewWriter(ctx)
	writer.ContentType = "application/octet-stream"
	if _, err := io.Copy(writer, source); err != nil {
		_ = writer.Close()
		return fmt.Errorf("upload %s to GCS object %s: %w", localPath, objectName, err)
	}
	if err := writer.Close(); err != nil {
		return fmt.Errorf("close GCS object %s: %w", objectName, err)
	}
	return nil
}

func writeParquetFile(path string, batch []readings.SensorReading) error {
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("create parquet file %s: %w", path, err)
	}
	defer file.Close()

	schema := SensorReadingSchema()
	builder := array.NewRecordBuilder(memory.DefaultAllocator, schema)
	defer builder.Release()

	for _, reading := range batch {
		builder.Field(0).(*array.TimestampBuilder).Append(arrow.Timestamp(reading.Time.UTC().UnixMicro()))
		builder.Field(1).(*array.StringBuilder).Append(reading.SensorID)
		builder.Field(2).(*array.StringBuilder).Append(reading.Metric)
		builder.Field(3).(*array.Float64Builder).Append(reading.Value)
		builder.Field(4).(*array.StringBuilder).Append(reading.Unit)
		builder.Field(5).(*array.StringBuilder).Append(reading.Source)
		builder.Field(6).(*array.Float64Builder).Append(reading.Latitude)
		builder.Field(7).(*array.Float64Builder).Append(reading.Longitude)
		builder.Field(8).(*array.Int16Builder).Append(reading.QualityFlag)
		builder.Field(9).(*array.TimestampBuilder).Append(arrow.Timestamp(reading.IngestedAt.UTC().UnixMicro()))
		builder.Field(10).(*array.Int32Builder).Append(int32(reading.SchemaVersion))
	}

	record := builder.NewRecord()
	defer record.Release()

	writer, err := pqarrow.NewFileWriter(
		schema,
		file,
		parquet.NewWriterProperties(parquet.WithMaxRowGroupLength(int64(len(batch)))),
		pqarrow.DefaultWriterProps(),
	)
	if err != nil {
		return fmt.Errorf("create parquet writer %s: %w", path, err)
	}
	if err := writer.Write(record); err != nil {
		return fmt.Errorf("write parquet file %s: %w", path, err)
	}
	if err := writer.Close(); err != nil {
		return fmt.Errorf("close parquet file %s: %w", path, err)
	}
	return nil
}

func partitionValue(value string) string {
	safe := partitionSafePattern.ReplaceAllString(value, "_")
	if safe == "" {
		return "unknown"
	}
	return safe
}
