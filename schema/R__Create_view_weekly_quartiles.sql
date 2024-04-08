CREATE OR REPLACE VIEW v_weekly_quartiles AS (
    WITH per_day AS (
        SELECT date_trunc('day', measured_on)               AS day,
               round(sum(production)  / 4 / 1000, 2)        AS production,
        FROM measurements
        GROUP BY day
    ), radiation_per_day AS (
        SELECT date_trunc('day', measured_on)               AS day,
               sum(shortwave_radiation) / 1000              AS kWh_mm
        FROM weather_data
        GROUP BY day
    )
    SELECT date_trunc('week', per_day.day)              AS sow,
           date_part('week', per_day.day)               AS week,
           min(production)                              AS min,
           quantile_cont(production, [0.25, 0.5, 0.75]) AS quartiles,
           max(production)                              AS max,
           round(avg(kWh_mm), 2)                        AS shortwave_radiation,
           CASE CAST(avg(cloud_cover_low)/25 AS int)
             WHEN 0 THEN '○'
             WHEN 1 THEN '◔'
             WHEN 2 THEN '◑'
             WHEN 3 THEN '◕'
             WHEN 4 THEN '●'
           END                                          AS cloud_coverage
    FROM per_day
    LEFT JOIN weather_data w ON date_trunc('day', w.measured_on) = per_day.day
    LEFT JOIN radiation_per_day USING (day)
    GROUP BY sow, week
    ORDER BY sow, week
);
