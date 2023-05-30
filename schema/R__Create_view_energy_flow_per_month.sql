CREATE OR REPLACE VIEW v_energy_flow_per_month AS (
    SELECT date_trunc('month', measured_on)      AS month,
           round(sum(production)  / 4 / 1000, 2) AS production,
           round(sum(consumption) / 4 / 1000, 2) AS consumption,
           round(sum(import) / 4 / 1000, 2)      AS import,
           round(sum(export)  / 4 / 1000, 2)     AS export
    FROM measurements
    GROUP BY rollup(month)
    ORDER BY month ASC NULLS LAST
);
