-- 0) Ingest CSVs
CREATE OR REPLACE TABLE industries_raw AS
SELECT * FROM read_csv_auto('C:/Users/Thoma/Desktop/people employment.csv', header = true);

CREATE OR REPLACE TABLE totals_raw AS
SELECT * FROM read_csv_auto('C:/Users/Thoma/Desktop/All Employment and Public Sector.csv', header = true);

-- 1) Clean (force numerics, keep Dates)
CREATE OR REPLACE VIEW industries_clean AS
SELECT
    Dates,
    TRY_CAST("Agriculture, forestry & fishing" AS DOUBLE)                           AS "Agriculture, forestry & fishing",
    TRY_CAST("Mining, energy and water supply" AS DOUBLE)                           AS "Mining, energy and water supply",
    TRY_CAST(Manufacturing AS DOUBLE)                                               AS Manufacturing,
    TRY_CAST(Construction AS DOUBLE)                                                AS Construction,
    TRY_CAST("Wholesale, retail & repair of motor vehicles" AS DOUBLE)              AS "Wholesale, retail & repair of motor vehicles",
    TRY_CAST("Transport & storage" AS DOUBLE)                                       AS "Transport & storage",
    TRY_CAST("Accommod-ation & food services" AS DOUBLE)                            AS "Accommod-ation & food services",
    TRY_CAST("Information & communication" AS DOUBLE)                               AS "Information & communication",
    TRY_CAST("Financial & insurance activities" AS DOUBLE)                          AS "Financial & insurance activities",
    TRY_CAST("Real estate activities" AS DOUBLE)                                    AS "Real estate activities",
    TRY_CAST("Professional, scientific & technical activities" AS DOUBLE)           AS "Professional, scientific & technical activities",
    TRY_CAST("Administrative & support services" AS DOUBLE)                         AS "Administrative & support services",
    TRY_CAST("Public admin & defence; social security" AS DOUBLE)                   AS "Public admin & defence; social security",
    TRY_CAST(Education AS DOUBLE)                                                   AS Education,
    TRY_CAST("Human health & social work activities" AS DOUBLE)                     AS "Human health & social work activities",
    TRY_CAST("Other services" AS DOUBLE)                                            AS "Other services"
FROM industries_raw;

-- 2) Long + de-dupe
CREATE OR REPLACE TABLE industries_long AS
SELECT
    dates_label,
    industry,
    MAX(employment) AS employment
FROM (
         SELECT Dates AS dates_label, industry, employment
         FROM industries_clean
                  UNPIVOT (employment FOR industry IN (* EXCLUDE (Dates)))
         WHERE employment IS NOT NULL
           AND TRIM(CAST(Dates AS VARCHAR)) <> ''
     ) u
GROUP BY 1,2;

-- 3) Totals (All in employment2) + de-dupe
CREATE OR REPLACE TABLE totals_long AS
SELECT
    dates_label,
    MAX(value) AS value
FROM (
    SELECT Dates AS dates_label, TRY_CAST("All in employment2" AS DOUBLE) AS value
    FROM totals_raw
    WHERE "All in employment2" IS NOT NULL
    ) t
GROUP BY 1;

-- 4) Periods
CREATE OR REPLACE VIEW periods AS
WITH d AS (
  SELECT DISTINCT dates_label FROM industries_long
  UNION
  SELECT DISTINCT dates_label FROM totals_long
),
y AS (
  SELECT
    dates_label,
    CAST(regexp_extract(dates_label, '([0-9]{4})', 1) AS INTEGER) AS year,
    CASE
      WHEN starts_with(dates_label,'Jan-Mar') THEN 1
      WHEN starts_with(dates_label,'Apr-Jun') THEN 2
      WHEN starts_with(dates_label,'Jul-Sep') THEN 3
      WHEN starts_with(dates_label,'Oct-Dec') THEN 4
    END AS qtr
  FROM d
)
SELECT
    dates_label,
    year,
    qtr,
    CASE qtr
    WHEN 1 THEN make_date(year, 1, 1)
    WHEN 2 THEN make_date(year, 4, 1)
    WHEN 3 THEN make_date(year, 7, 1)
    WHEN 4 THEN make_date(year,10, 1)
END AS quarter_start
FROM y;

-- 5) Density and a de-duplicated view
CREATE OR REPLACE TABLE industry_density AS
SELECT
    i.dates_label,
    p.quarter_start,
    p.year,
    p.qtr,
    i.industry,
    CAST(i.employment AS DOUBLE) / CAST(t.value AS DOUBLE) AS density
FROM industries_long i
         JOIN totals_long t USING (dates_label)
         JOIN periods     p USING (dates_label);

CREATE OR REPLACE VIEW industry_density_uniq AS
SELECT industry, quarter_start, MAX(density) AS density
FROM industry_density
GROUP BY 1,2;

-- 6) Final summary view (1997 Q1 vs 2025 Q2)
CREATE OR REPLACE VIEW v_industry_density_summary_1997_2025 AS
WITH params(start_q, end_q) AS (
  VALUES (DATE '1997-01-01', DATE '2025-04-01')  -- change end_q if needed
),
start_1997 AS (
  SELECT u.industry, ROUND(100 * u.density, 2) AS start_density_1997
  FROM industry_density_uniq u, params p
  WHERE u.quarter_start = p.start_q
),
end_2025 AS (
  SELECT u.industry, ROUND(100 * u.density, 2) AS end_density_2025
  FROM industry_density_uniq u, params p
  WHERE u.quarter_start = p.end_q
)
SELECT
    s.industry                                 AS "Industry",
    s.start_density_1997                       AS "Start Density (1997)",
    e.end_density_2025                         AS "End Density (2025)",
    ROUND(e.end_density_2025 - s.start_density_1997, 2) AS "Density Change (2025)"
FROM start_1997 s
         JOIN end_2025 e USING (industry)
ORDER BY "Density Change (2025)" DESC NULLS LAST;


SELECT *
FROM v_industry_density_summary_1997_2025
ORDER BY "Density Change (2025)" DESC;
