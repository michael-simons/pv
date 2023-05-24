CREATE OR REPLACE VIEW selling_prices AS (
    -- Make sure we have a list of consecutive prices by traversing them recursively
    WITH RECURSIVE sell(valid_from, valid_until, value, type) AS (
        SELECT valid_from, valid_until, value, p.type FROM prices p
        WHERE type IN ('partial_sell', 'full_sell') AND NOT EXISTS (SELECT '' FROM prices o WHERE o.type = p.type AND o.valid_from < p.valid_from AND valid_until IS NOT NULL)
        UNION ALL
        SELECT p.valid_from, p.valid_until, p.value, p.type
        FROM prices p, sell
        WHERE p.type = sell.type
          AND p.valid_from = sell.valid_until + INTERVAL 1 DAY
    )
    SELECT sell.valid_from    AS valid_from,
           sell.valid_until   AS valid_until,
           sell.value         AS value,
           sell.type          AS type
    FROM sell
    ORDER BY valid_from ASC
);
