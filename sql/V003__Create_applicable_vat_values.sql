CREATE TABLE IF NOT EXISTS applicable_vat_values (
    valid_from  DATE NOT NULL PRIMARY KEY,
    valid_until DATE,
    value       DECIMAL(3,2) NOT NULL -- Value in percent
);

