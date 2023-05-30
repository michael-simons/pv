CREATE OR REPLACE VIEW v_energy_flow_per_day AS (
    SELECT date_trunc('day', measured_on)        AS day,
           round(sum(production)  / 4 / 1000, 2) AS production,
           round(sum(consumption) / 4 / 1000, 2) AS consumption,
           round(sum(import) / 4 / 1000, 2)      AS import,
           round(sum(export)  / 4 / 1000, 2)     AS export
    FROM measurements
    GROUP BY day
);
