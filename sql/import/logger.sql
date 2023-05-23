load icu;
SET TimeZone='Europe/Berlin';

WITH input AS (
    SELECT date_trunc('minute', time_bucket(INTERVAL '15 Minutes', measured_on::timestamptz)) AS ts,
           avg(power) AS power
    FROM read_csv_auto('logger.csv', header=false, names=['measured_on', 'power'])
    GROUP BY ts
    ORDER BY ts ASC
)
INSERT INTO measurements (measured_on, production)
SELECT ts, power
FROM input
ON CONFLICT (measured_on) DO UPDATE
SET production = CASE
  WHEN production = 0 THEN excluded.production
  ELSE (production + excluded.production) / 2 END
;
