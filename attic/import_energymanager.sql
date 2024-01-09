load icu;
SET TimeZone='Europe/Berlin';

WITH input AS (
    SELECT strptime(DateTime, '%Y-%m-%d %H:%M')::timestamptz AS ts,
           power
    FROM read_csv_auto('/dev/stdin', names=['DateTime', 'power'])
)
INSERT INTO measurements (measured_on, production)
SELECT ts, power
FROM input
ON CONFLICT (measured_on) DO UPDATE
SET production = CASE
  WHEN production = 0 THEN excluded.production
  WHEN production < excluded.production THEN (production + excluded.production) / 2
  ELSE production END
;
