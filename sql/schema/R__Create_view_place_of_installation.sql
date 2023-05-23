CREATE OR REPLACE VIEW place_of_installation AS (
    SELECT (SELECT coalesce(cast(any_value(value) AS decimal(7,5)), 50.775555) FROM domain_values WHERE name = 'LATITUDE') AS lat,
           (SELECT coalesce(cast(any_value(value) AS decimal(7,5)), 6.083611) FROM domain_values WHERE name = 'LONGITUDE') AS long
);
