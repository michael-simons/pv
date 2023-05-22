-- This script reads its import from stdin

load icu;
SET TimeZone='Europe/Berlin';

SELECT count(*) AS 'before' FROM production;

WITH input AS (
    SELECT date_trunc('minute', time_bucket(INTERVAL '15 Minutes', measured_on::timestamptz)) AS ts,
           avg(power) AS power
    FROM read_csv_auto('/dev/stdin', header=false, names=['measured_on', 'power'])
    GROUP BY ts
    ORDER BY ts ASC
)
INSERT INTO production (measured_on, power)
SELECT ts, power
FROM input
ON CONFLICT (measured_on) DO UPDATE
SET power = CASE
  WHEN power = 0 THEN excluded.power
  ELSE (power + excluded.power) / 2 END
;

SELECT count(*) AS 'after' FROM production;