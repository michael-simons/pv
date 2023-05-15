INSERT INTO domain_values (name, value, description)
VALUES ('INSTALLED_PEAK_POWER', '10.53', 'The installed peak power in kilowatt (kW), usually dubbed kWp.')
    ON CONFLICT (name) DO NOTHING;

INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1968-01-01', '1968-06-30', 0.1)  ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1968-07-01', '1977-12-31', 0.11) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1978-01-01', '1979-06-30', 0.12) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1979-07-01', '1983-06-30', 0.13) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1983-07-01', '1992-12-31', 0.14) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1993-01-01', '1998-03-31', 0.15) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('1998-04-01', '2006-12-31', 0.16) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('2007-01-01', '2020-06-30', 0.19) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('2020-07-01', '2020-12-31', 0.16) ON CONFLICT DO NOTHING;
INSERT INTO applicable_vat_values(valid_from,valid_until, value) VALUES('2021-01-01', null,         0.19) ON CONFLICT DO NOTHING;
