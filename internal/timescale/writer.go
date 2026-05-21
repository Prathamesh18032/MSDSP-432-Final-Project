package timescale

import (
	"context"
	"fmt"
	"time"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/buffer"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type Writer struct {
	pool *pgxpool.Pool
}

type ExportReadingsQuery struct {
	Before *time.Time
	Limit  int
}

func Connect(ctx context.Context, dsn string) (*Writer, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("create pgx pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping timescaledb: %w", err)
	}

	return &Writer{pool: pool}, nil
}

func (w *Writer) Close() {
	w.pool.Close()
}

func (w *Writer) InsertReadings(ctx context.Context, batch []readings.SensorReading) error {
	if len(batch) == 0 {
		return nil
	}

	tx, err := w.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	for _, reading := range batch {
		_, err := tx.Exec(ctx, `
			INSERT INTO sensor_readings (
				time,
				sensor_id,
				metric,
				value,
				unit,
				source,
				latitude,
				longitude,
				quality_flag,
				ingested_at,
				schema_version
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
			ON CONFLICT (time, sensor_id, metric) DO UPDATE SET
				value = EXCLUDED.value,
				unit = EXCLUDED.unit,
				source = EXCLUDED.source,
				latitude = EXCLUDED.latitude,
				longitude = EXCLUDED.longitude,
				quality_flag = EXCLUDED.quality_flag,
				ingested_at = EXCLUDED.ingested_at,
				schema_version = EXCLUDED.schema_version
		`,
			reading.Time,
			reading.SensorID,
			reading.Metric,
			reading.Value,
			reading.Unit,
			reading.Source,
			reading.Latitude,
			reading.Longitude,
			reading.QualityFlag,
			reading.IngestedAt,
			reading.SchemaVersion,
		)
		if err != nil {
			return fmt.Errorf("insert reading %s: %w", reading.DedupKey(), err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit readings: %w", err)
	}

	return nil
}

func (w *Writer) ExportReadings(ctx context.Context, query ExportReadingsQuery) ([]readings.SensorReading, error) {
	if query.Limit <= 0 {
		return nil, fmt.Errorf("export limit must be positive")
	}

	var cutoff any
	if query.Before != nil {
		cutoff = query.Before.UTC()
	}

	rows, err := w.pool.Query(ctx, `
		SELECT
			time,
			sensor_id,
			metric,
			value,
			unit,
			source,
			latitude,
			longitude,
			quality_flag,
			ingested_at,
			schema_version
		FROM sensor_readings
		WHERE ($1::timestamptz IS NULL OR time < $1::timestamptz)
		ORDER BY time, source, metric, sensor_id
		LIMIT $2
	`, cutoff, query.Limit)
	if err != nil {
		return nil, fmt.Errorf("query export readings: %w", err)
	}
	defer rows.Close()

	result := make([]readings.SensorReading, 0)
	for rows.Next() {
		var reading readings.SensorReading
		if err := rows.Scan(
			&reading.Time,
			&reading.SensorID,
			&reading.Metric,
			&reading.Value,
			&reading.Unit,
			&reading.Source,
			&reading.Latitude,
			&reading.Longitude,
			&reading.QualityFlag,
			&reading.IngestedAt,
			&reading.SchemaVersion,
		); err != nil {
			return nil, fmt.Errorf("scan export reading: %w", err)
		}
		result = append(result, reading)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate export readings: %w", err)
	}

	return result, nil
}

func (w *Writer) RecordIngestionMetrics(ctx context.Context, metric buffer.IngestionMetric) error {
	if metric.RecordedAt.IsZero() {
		return fmt.Errorf("recorded_at is required")
	}

	_, err := w.pool.Exec(ctx, `
		INSERT INTO ingestion_metrics (
			recorded_at,
			readings_per_second,
			channel_fill_pct,
			pubsub_lag_ms,
			gcs_write_latency_ms,
			dropped_readings_total
		)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (recorded_at) DO UPDATE SET
			readings_per_second = EXCLUDED.readings_per_second,
			channel_fill_pct = EXCLUDED.channel_fill_pct,
			pubsub_lag_ms = EXCLUDED.pubsub_lag_ms,
			gcs_write_latency_ms = EXCLUDED.gcs_write_latency_ms,
			dropped_readings_total = EXCLUDED.dropped_readings_total
	`,
		metric.RecordedAt,
		metric.ReadingsPerSecond,
		metric.ChannelFillPct,
		metric.PubSubLagMillis,
		metric.GCSWriteLatencyMS,
		metric.DroppedReadingsTotal,
	)
	if err != nil {
		return fmt.Errorf("insert ingestion metrics: %w", err)
	}
	return nil
}
