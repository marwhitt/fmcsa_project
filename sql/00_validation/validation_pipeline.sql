-- ============================================================
-- validation_pipeline.sql
-- FMCSA carrier safety project: validation checkpoints
--
-- Before running: find-and-replace  your_project.fmcsa  with
-- YOUR_PROJECT_ID.fmcsa  (REPRODUCE.md Step 6).
--
-- Run each section at the checkpoint REPRODUCE.md calls out.
-- Section 1 runs immediately after the three `bq load` jobs.
-- ============================================================


-- ============================================================
-- SECTION 1: RAW BASELINE
-- Run right after loading raw_census, raw_crashes, raw_inspections.
-- Record 1.1's counts in DOWNLOADS.md as the official row counts
-- for snapshot 2026-07-27.
-- ============================================================

-- 1.1 Row counts per raw table (the snapshot baseline)
SELECT 'raw_census' AS table_name, COUNT(*) AS row_count
FROM `your_project.fmcsa.raw_census`
UNION ALL
SELECT 'raw_crashes', COUNT(*)
FROM `your_project.fmcsa.raw_crashes`
UNION ALL
SELECT 'raw_inspections', COUNT(*)
FROM `your_project.fmcsa.raw_inspections`
ORDER BY table_name;

-- 1.2 Join-key health: DOT_NUMBER must be present to be usable.
-- Expect near-zero nulls/blanks; anything else goes in data_quality_log.md.
SELECT 'raw_census' AS table_name,
       COUNT(*) AS total_rows,
       COUNTIF(NULLIF(TRIM(CAST(DOT_NUMBER AS STRING)), '') IS NULL) AS missing_dot_number,
       COUNT(DISTINCT DOT_NUMBER) AS distinct_carriers
FROM `your_project.fmcsa.raw_census`
UNION ALL
SELECT 'raw_crashes',
       COUNT(*),
       COUNTIF(NULLIF(TRIM(CAST(DOT_NUMBER AS STRING)), '') IS NULL),
       COUNT(DISTINCT DOT_NUMBER)
FROM `your_project.fmcsa.raw_crashes`
UNION ALL
SELECT 'raw_inspections',
       COUNT(*),
       COUNTIF(NULLIF(TRIM(CAST(DOT_NUMBER AS STRING)), '') IS NULL),
       COUNT(DISTINCT DOT_NUMBER)
FROM `your_project.fmcsa.raw_inspections`
ORDER BY table_name;

-- 1.3 Date ranges and parse health.
-- Dates are YYYYMMDD; SAFE.PARSE_DATE returns NULL on garbage instead of failing.
-- unparseable > 0 is fine in small numbers; log the magnitude.
SELECT 'raw_crashes.REPORT_DATE' AS date_field,
       MIN(SAFE.PARSE_DATE('%Y%m%d', CAST(REPORT_DATE AS STRING))) AS min_date,
       MAX(SAFE.PARSE_DATE('%Y%m%d', CAST(REPORT_DATE AS STRING))) AS max_date,
       COUNTIF(REPORT_DATE IS NOT NULL
               AND SAFE.PARSE_DATE('%Y%m%d', CAST(REPORT_DATE AS STRING)) IS NULL) AS unparseable
FROM `your_project.fmcsa.raw_crashes`
UNION ALL
SELECT 'raw_inspections.INSP_DATE',
       MIN(SAFE.PARSE_DATE('%Y%m%d', CAST(INSP_DATE AS STRING))),
       MAX(SAFE.PARSE_DATE('%Y%m%d', CAST(INSP_DATE AS STRING))),
       COUNTIF(INSP_DATE IS NOT NULL
               AND SAFE.PARSE_DATE('%Y%m%d', CAST(INSP_DATE AS STRING)) IS NULL)
FROM `your_project.fmcsa.raw_inspections`;
-- Expectations for snapshot 2026-07-27:
--   raw_inspections: roughly 2023-07 through 2026-07 (rolling 3-year window).
--   raw_crashes: min_date may be as early as 1982; early years are sparse
--   and partly data-entry noise. The analytical window (2020-2024) is
--   applied in staging, not here.

-- 1.4 Crash rows by year: sanity-check the 2020-2024 analytical window
-- has healthy volume, and see how thin the early years are.
SELECT EXTRACT(YEAR FROM SAFE.PARSE_DATE('%Y%m%d', CAST(REPORT_DATE AS STRING))) AS crash_year,
       COUNT(*) AS involvement_rows,
       COUNT(DISTINCT CRASH_ID) AS distinct_crashes
FROM `your_project.fmcsa.raw_crashes`
GROUP BY crash_year
ORDER BY crash_year DESC;

-- 1.5 Census composition: status and Texas share (the analysis population).
SELECT STATUS_CODE,
       COUNT(*) AS carriers,
       COUNTIF(UPPER(TRIM(CAST(PHY_STATE AS STRING))) = 'TX') AS tx_carriers
FROM `your_project.fmcsa.raw_census`
GROUP BY STATUS_CODE
ORDER BY carriers DESC;


-- ============================================================
-- SECTION 2: STAGING CHECKS  (run after sql/02_staging/*.sql)
-- TODO with the staging layer: row deltas raw -> staged (TX filter),
-- duplicate checks on keys, OOS flag distributions, severity classes.
-- ============================================================

-- ============================================================
-- SECTION 3: MART CHECKS  (run after sql/03_mart/*.sql)
-- TODO: one-row-per-carrier uniqueness in mart_carrier_profile,
-- KPI ranges (no negative rates), carrier-year completeness.
-- ============================================================

-- ============================================================
-- SECTION 4: BENCHMARK SANITY  (run after mart_industry_benchmarks)
-- TODO: medians fall inside observed ranges, percentile ordering
-- p10 <= p50 <= p90, every size bucket + year has a row.
-- ============================================================

-- ============================================================
-- SECTION 5: NAMED-CARRIER SPOT CHECKS  (run last)
-- TODO: pick 3-5 known Texas carriers, compare their KPI values
-- against SAFER / A&I public figures for the same period.
-- ============================================================
