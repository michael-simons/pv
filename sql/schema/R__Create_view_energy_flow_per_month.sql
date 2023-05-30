DROP VIEW IF EXISTS production_per_month;
CREATE OR REPLACE VIEW energy_flow_per_month AS (
    SELECT date_trunc('month', measured_on)      AS Month,
           round(sum(production)  / 4 / 1000, 2) AS 'Production (kWh)',
           round(sum(consumption) / 4 / 1000, 2) AS 'Consumption (kWh',
           round(sum(export)  / 4 / 1000, 2)     AS 'Export (kWh)',
           round(sum(import) / 4 / 1000, 2)      AS 'Import (kWh)'
    FROM measurements
    GROUP BY rollup(Month)
    ORDER BY Month ASC NULLS LAST
);
