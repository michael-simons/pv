load icu;
SET TimeZone='Europe/Berlin';

WITH input AS (
    SELECT date_trunc('minute', time_bucket(INTERVAL '15 Minutes', DateTime::timestamptz)) AS ts,
           avg(cast(replace(coalesce(Leistung,'0'), ',', '.') as numeric)) * 1000 AS power
    FROM read_csv_auto('/dev/stdin')
    GROUP BY ts
)
INSERT INTO measurements (measured_on, production)
SELECT ts, power
FROM input
ON CONFLICT (measured_on) DO UPDATE SET production = excluded.production;
