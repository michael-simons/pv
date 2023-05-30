CREATE OR REPLACE VIEW overall_production AS (
    WITH per_day AS (
        SELECT sum(production) / 4 / 1000 AS v
        FROM measurements
        GROUP BY date_trunc('day', measured_on)
    ), totals AS (
      SELECT round(min(v), 2)    AS worst,
             round(max(v), 2)    AS best,
             round(avg(v), 2)    AS daily_avg,
             round(median(v), 2) AS daily_median,
             round(sum(v), 2)    AS total
      FROM per_day
      WHERE v <> 0
    )
    SELECT totals.worst,
           totals.best,
           totals.daily_avg,
           totals.daily_median,
           totals.total,
           CAST (CASE WHEN dv.value IS NULL THEN NULL
                      ELSE round(totals.total / CAST(dv.value AS NUMERIC), 2) END AS NUMERIC)
                               AS total_yield
    FROM totals LEFT OUTER JOIN domain_values dv ON (dv.name = 'INSTALLED_PEAK_POWER')
);
