CREATE OR REPLACE VIEW production_per_day AS (
    SELECT date_trunc('day', measured_on)       AS Day,
           round(sum(production) / 4 / 1000, 2) AS 'Energy (kWh)'
    FROM measurements
    GROUP BY Day
);
