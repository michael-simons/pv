load icu;
SET TimeZone='Europe/Berlin';

WITH input AS (
    SELECT strptime(DateTime, '%Y-%m-%d %H:%M')::timestamptz AS ts,
           power
    FROM read_csv_auto('energymanager.csv', names=['DateTime', 'power'])
)
INSERT INTO production (measured_on, power)
SELECT ts, power
FROM input
ON CONFLICT (measured_on) DO UPDATE
SET power = CASE
  WHEN power = 0 THEN excluded.power
  WHEN power < excluded.power THEN (power + excluded.power) / 2
  ELSE power END
;
