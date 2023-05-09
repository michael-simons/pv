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
ON CONFLICT (measured_on) DO UPDATE SET power = excluded.power WHERE power = 0.0;
