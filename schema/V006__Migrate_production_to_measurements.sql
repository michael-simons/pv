CREATE TABLE IF NOT EXISTS measurements (
    measured_on TIMESTAMP PRIMARY KEY,
    production  DECIMAL(8,3) NOT NULL DEFAULT 0,
    consumption DECIMAL(8,3) NOT NULL DEFAULT 0,
    import DECIMAL(8,3)      NOT NULL DEFAULT 0,
    export DECIMAL(8,3)      NOT NULL DEFAULT 0
);

INSERT INTO measurements (measured_on, production)
SELECT measured_on, power FROM production ORDER BY measured_on ASC
ON CONFLICT (measured_on) DO NOTHING;

DROP TABLE IF EXISTS production;
