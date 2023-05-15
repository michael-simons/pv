CREATE OR REPLACE VIEW buying_prices AS (
    -- Make sure we have a list of consecutive prices by traversing them recursively
    WITH RECURSIVE buy(valid_from, valid_until, value) AS (
        SELECT valid_from, valid_until, value FROM prices p
        WHERE type = 'buy' AND NOT EXISTS (SELECT '' FROM prices o WHERE o.type = p.type AND o.valid_from < p.valid_from) AND valid_until IS NOT NULL
        UNION ALL
        SELECT p.valid_from, p.valid_until, p.value
        FROM prices p, buy
        WHERE p.type = 'buy'
          AND p.valid_from = buy.valid_until + INTERVAL 1 DAY
    )
    SELECT greatest(buy.valid_from, vat.valid_from) AS valid_from,
           least(buy.valid_until, vat.valid_until)  AS valid_until,
           buy.value                                AS net,
           round((buy.value - coalesce(lag(buy.value) OVER (ORDER BY greatest(buy.valid_from, vat.valid_from)), buy.value)) / coalesce(lag(buy.value) OVER (ORDER BY greatest(buy.valid_from, vat.valid_from)), buy.value), 4)
                                                    AS change,
           vat.value                                AS tax,
           round(buy.value * (vat.value + 1.0), 2)  AS gross
    FROM buy
    -- Join in all valid applicable taxes in the validity period of the price
    JOIN applicable_vat_values vat ON (
        vat.valid_from >= buy.valid_from AND vat.valid_from <= buy.valid_until OR
        vat.valid_from < buy.valid_from  AND coalesce(vat.valid_until, current_date()) > buy.valid_from
    )
    ORDER BY valid_from ASC
);
