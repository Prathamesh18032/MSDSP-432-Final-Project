package timescale

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Prathamesh18032/MSDSP-432-Final-Project/internal/readings"
)

type Writer struct {
	pool *pgxpool.Pool
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
