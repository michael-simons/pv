-- This script reads its import from stdin

install icu;
load icu;
SET TimeZone='Europe/Berlin';

SELECT count(*) AS 'before' FROM measurements;

WITH input AS (
    SELECT time_bucket(INTERVAL '15 Minutes', ts::timestamptz) AS _measured_on,
           avg(production)  AS _production,
           avg(consumption) AS _consumption,
           avg(export)      AS _export,
           avg(import)      AS _import
    FROM read_csv_auto('/dev/stdin', delim=",", header=true)
    GROUP BY _measured_on
    ORDER BY _measured_on ASC
)
INSERT INTO measurements (measured_on, production, consumption, export, import)
SELECT * FROM input
ON CONFLICT (measured_on) DO UPDATE
SET production = CASE
        WHEN production = 0 THEN excluded.production
        ELSE (production + excluded.production) / 2 END,
    consumption = excluded.consumption,
    export = excluded.export,
    import = excluded.import
;

SELECT count(*) AS 'after' FROM measurements;
