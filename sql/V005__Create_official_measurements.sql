CREATE SEQUENCE IF NOT EXISTS official_measurements_primary_key_seq;
CREATE TABLE IF NOT EXISTS official_measurements (
    id           INTEGER PRIMARY KEY DEFAULT(nextval('official_measurements_primary_key_seq')),
    period_start DATE NOT NULL,
    period_end   DATE NOT NULL,
    import       DECIMAL(7,2) NOT NULL, -- Imported energy in kWH
    export       DECIMAL(7,2) NULL, -- Exporte energy in kWH
    CONSTRAINT official_measurements UNIQUE (period_start, period_end)
);
