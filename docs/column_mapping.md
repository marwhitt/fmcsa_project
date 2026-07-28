# Column Mapping: Downloaded Headers to Staging SQL Names

Snapshot: `FMCSA_*_20260727.csv`. Headers below were read directly from the downloaded files (verified 2026-07-28), not assumed from documentation.

General notes that apply everywhere:

1. Headers arrive UPPERCASE, with one census oddity: `HM_Ind`. BigQuery identifiers are case-insensitive in SQL, so `hm_ind` and `HM_IND` both work in queries.
2. All date fields are `YYYYMMDD` values with no separators. Under `--autodetect` they typically load as INT64. Parse defensively everywhere: `SAFE.PARSE_DATE('%Y%m%d', CAST(col AS STRING))`.
3. Times are `HHMM`. Audit stamps like `CHANGE_DATE` are `YYYYMMDD HHMM` strings.
4. All three tables join on `DOT_NUMBER`.

## Census: FMCSA_CENSUS1_*.csv → `fmcsa.raw_census`

| Staging SQL expects | Actual column | Action |
|---|---|---|
| `USDOT_NUMBER` | `DOT_NUMBER` | Rename |
| `PHYS_STATE` | `PHY_STATE` | Rename (this is also the Texas filter column) |
| `MCS_150_MILEAGE` | `MCS150_MILEAGE` | Rename; always carry `MCS150_MILEAGE_YEAR` alongside it |
| `HM_FLAG` | `HM_Ind` | Rename; values are Y/N |
| `INTERSTATE` | `CARRIER_OPERATION` | Transform, not a rename: `'A'` = interstate, `'B'` = intrastate hazmat, `'C'` = intrastate non-hazmat. Use `CASE WHEN CARRIER_OPERATION = 'A' THEN TRUE ELSE FALSE END`, or keep all three codes as a dimension |

Also present and useful for this analysis: `LEGAL_NAME`, `DBA_NAME`, `STATUS_CODE` (A = active, I = inactive), `POWER_UNITS`, `TRUCK_UNITS`, `BUS_UNITS`, `TOTAL_DRIVERS`, `TOTAL_CDL`, `SAFETY_RATING`, `SAFETY_RATING_DATE`, `ADD_DATE`, plus the `CRGO_*` cargo-type flags for freight/passenger classification.

## Crash: FMCSA_CRASH_*.csv → `fmcsa.raw_crashes`

| Staging SQL expects | Actual column | Action |
|---|---|---|
| `CRASH_DATE` | `REPORT_DATE` | Rename + parse `YYYYMMDD` |
| `FATALITIES` | `FATALITIES` | None |

Grain reminder: one row per carrier/vehicle involvement. A unique crash is `CRASH_ID` (or `REPORT_STATE` + `REPORT_NUMBER`); `REPORT_SEQ_NO` sequences involvements within a report. Severity fields: `FATALITIES`, `INJURIES`, `TOW_AWAY` (Y/N), `FEDERAL_RECORDABLE` (Y/N), `STATE_RECORDABLE` (Y/N). Filter decisions on recordability belong in staging, documented in the plan.

## Inspection: FMCSA_INSPECTION_*.csv → `fmcsa.raw_inspections`

| Staging SQL expects | Actual column | Action |
|---|---|---|
| `INSP_DATE` | `INSP_DATE` | None (parse `YYYYMMDD`) |
| `DRV_OUT_OF_SERVICE` | `DRIVER_OOS_TOTAL` | Transform: numeric count, not Y/N. `CASE WHEN SAFE_CAST(DRIVER_OOS_TOTAL AS INT64) > 0 THEN TRUE ELSE FALSE END` (exactly the swap REPRODUCE.md Step 2 anticipates) |
| `VEH_OUT_OF_SERVICE` | `VEHICLE_OOS_TOTAL` | Same transform |
| `HOS_VIOL_COUNT` | (absent) | Not in this file. Only totals exist: `VIOL_TOTAL`, `OOS_TOTAL`, and driver/vehicle/hazmat viol + OOS totals. Per-category violation counts (hours-of-service, maintenance, etc.) require FMCSA's separate "Vehicle Inspections and Violations" dataset. Log this in `data_quality_log.md`; the violation-by-category KPI is out of scope unless that dataset is added |

Other fields worth knowing: `INSP_LEVEL_ID` (inspection level 1-6, a required dashboard dimension), `INSP_CARRIER_NAME`, `INSP_CARRIER_STATE`, `POST_ACC_IND` (post-accident inspection flag).
