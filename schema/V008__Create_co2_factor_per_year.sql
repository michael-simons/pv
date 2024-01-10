CREATE TABLE IF NOT EXISTS co2_factor_per_year (
    year        INTEGER PRIMARY KEY,
    value       INTEGER NOT NULL -- in g/kWh
);

DELETE FROM co2_factor_per_year;

-- Source for Germany: https://www.umweltbundesamt.de/themen/co2-emissionen-pro-kilowattstunde-strom-stiegen-in
INSERT INTO co2_factor_per_year (year, value) VALUES
  (1990, 764),
  (1991, 764),
  (1992, 730),
  (1993, 726),
  (1994, 722),
  (1995, 713),
  (1996, 684),
  (1997, 668),
  (1998, 670),
  (1999, 647),
  (2000, 644),
  (2001, 659),
  (2002, 653),
  (2003, 635),
  (2004, 615),
  (2005, 611),
  (2006, 604),
  (2007, 622),
  (2008, 581),
  (2009, 567),
  (2010, 556),
  (2011, 568),
  (2012, 574),
  (2013, 573),
  (2014, 559),
  (2015, 528),
  (2016, 524),
  (2017, 486),
  (2018, 473),
  (2019, 411),
  (2020, 369),
  (2021, 410),
  (2022, 434)
  ON CONFLICT DO NOTHING;
