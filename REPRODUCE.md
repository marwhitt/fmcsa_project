# Reproducing This Analysis

From zero to running analytical tables in ~30 minutes with a free GCP account.

**Snapshot date used in this analysis:** `2026-07-21` (DOT portal retrieval; portal "last updated": census 2026-07-10, crash 2026-07-08, inspections 2026-07-05. Full detail in `DOWNLOADS.md`.)
**BigQuery project used:** `[FILL IN YOUR GCP PROJECT ID]`

---

## Prerequisites

Before you start, confirm you have:

- [x] A Google account
- [x] A GCP project created at [console.cloud.google.com](https://console.cloud.google.com)
  — free tier is sufficient; set a billing alert at $1 as a safeguard
- [x] The `bq` CLI installed: [cloud.google.com/bigquery/docs/bq-command-line-tool](https://cloud.google.com/bigquery/docs/bq-command-line-tool)
  — or use the BigQuery web console to run SQL; `bq load` is the only CLI command required
- [x] ~7 GB of local disk space for the FMCSA downloads (full portal exports; see Step 1)

---

## Step 1 — Download the FMCSA files

> **Source update (2026-07-21):** The FMCSA DataHub page originally linked here
> (`fmcsa.dot.gov/safety/carrier-safety/carrier-data-reports`) has been retired and now returns 404.
> The same three MCMIS extracts are published on the DOT Open Data Portal (data.transportation.gov)
> as direct CSV exports, refreshed roughly daily. There is no zip step and no monthly snapshot
> anymore: the snapshot date is simply the day you download. Direct links, dataset IDs, row counts,
> and field lists are in `DOWNLOADS.md`; `fmcsa_download_kit.html` is a one-click download page.

Download all three files:

| File | Current dataset (ID) | What it contains |
|---|---|---|
| **Motor Carrier Census Data** | Company Census File (`az4n-8mr2`) | One row per carrier: identity, fleet size, VMT, flags |
| **Large Truck and Bus Crash Data** | Crash File (`aayw-vxb3`) | One row per crash involvement |
| **Motor Carrier Inspection Data** | Vehicle Inspection File (`fx4q-ay7w`) | One row per roadside inspection |

Easiest route: run a download script from the repo root. Both scripts write into `data/raw/` with
the exact filenames Step 5 expects (`FMCSA_CENSUS1_<date>.csv`, `FMCSA_CRASH_<date>.csv`,
`FMCSA_INSPECTION_<date>.csv`):

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts\get_fmcsa_data.ps1
```

```bash
# Git Bash / WSL / macOS
bash scripts/get_fmcsa_data.sh
```

Notes for the new source: files are comma-delimited (the Step 3 pipe check should come up clean),
headers are lowercase (`dot_number`, `mcs150_mileage`, `driver_oos_total`, ...) so expect to use the
"common alternates" column in Step 2, and the full exports total roughly 7 GB: the crash file now
carries multi-decade history and the census includes inactive carriers. The Texas 2020-2024 scope
is applied later in staging SQL, or you can pre-filter smaller slices via the portal API
(endpoints in `DOWNLOADS.md`).

**Record the snapshot date** (the retrieval date in `DOWNLOADS.md`). Add it to the top of this file and to `README.md`. *(Done for 2026-07-21.)*

---

## Step 2 — Check your CSV headers before loading anything

FMCSA field names vary slightly across snapshot versions. This is the most common source of errors.

Open each file in Excel or run `head -1 filename.csv` in your terminal and compare to this list:

| What the SQL expects | Common alternates — rename if needed |
|---|---|
| `USDOT_NUMBER` | `DOT_NUMBER`, `CARRIER_ID_NUMBER` |
| `PHYS_STATE` | `PHY_STATE`, `STATE` |
| `MCS_150_MILEAGE` | `MCS150_MILEAGE`, `ANNUAL_MILEAGE` |
| `HM_FLAG` | `HM_CARRIER_FLAG`, `HAZMAT_FLAG` |
| `INTERSTATE` | `INTERSTATE_FLAG` |
| `CRASH_DATE` | `ACCIDENT_DATE`, `REPORT_DATE` |
| `FATALITIES` | `FAT`, `FATAL` |
| `INSP_DATE` | `INSPECTION_DATE` |
| `DRV_OUT_OF_SERVICE` | `DRVR_OOS_TOTAL` (numeric — see note below) |
| `VEH_OUT_OF_SERVICE` | `VEH_OOS_TOTAL` (numeric — see note below) |
| `HOS_VIOL_COUNT` | May be absent — see note below |

**OOS field note:** If `DRV_OUT_OF_SERVICE` is numeric (a count rather than Y/N), update the CASE statement in `stg_inspections.sql`:
```sql
-- Change this:
CASE UPPER(TRIM(DRV_OUT_OF_SERVICE)) WHEN 'Y' THEN TRUE ...
-- To this:
CASE WHEN SAFE_CAST(DRVR_OOS_TOTAL AS INT64) > 0 THEN TRUE ELSE FALSE END
```

**Violation column note:** If your inspection file has a single violation string instead of per-category columns, note it in `data_quality_log.md` — we will handle the parsing in the mart layer.

---

## Step 3 — Check the delimiter

FMCSA files are sometimes pipe-delimited (`|`) rather than comma-delimited. Check one row:

```bash
head -2 your_census_file.csv | cat -A
```

If you see `|` between fields, add `--field_delimiter='|'` to the `bq load` commands in Step 5.

---

## Step 4 — Create the BigQuery dataset

```bash
# Replace YOUR_PROJECT_ID with your GCP project ID
bq mk --dataset --location=US YOUR_PROJECT_ID:fmcsa
```

Verify in the BigQuery console that the `fmcsa` dataset exists before continuing.

---

## Step 5 — Load raw tables

Run these three commands. Replace `YOUR_PROJECT_ID` and the filenames with your actual paths.

```bash
# Census / Company data
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  YOUR_PROJECT_ID:fmcsa.raw_census \
  ./data/raw/FMCSA_CENSUS1_[date].csv

# Crash data
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  YOUR_PROJECT_ID:fmcsa.raw_crashes \
  ./data/raw/FMCSA_CRASH_[date].csv

# Inspection data
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  YOUR_PROJECT_ID:fmcsa.raw_inspections \
  ./data/raw/FMCSA_INSPECTION_[date].csv
```

> If your files are pipe-delimited, add `--field_delimiter='|'` to each command.
> If autodetect misreads a column type, use `--schema` with an explicit schema file instead — instructions in the BigQuery docs.
> Free-tier note: full raw loads can approach BigQuery's 10 GB free storage cap. If you hit it, drop the raw_* tables once staging tables are built, or load pre-filtered slices instead.

**After loading, immediately run Section 1 of `sql/00_validation/validation_pipeline.sql`** and record the row counts. These are your baseline.

---

## Step 6 — Update the project reference in all SQL files

Every SQL file contains `your_project.fmcsa`. Before running anything, find-and-replace across the entire `sql/` folder:

```
Find:    your_project.fmcsa
Replace: YOUR_PROJECT_ID.fmcsa
```

In VS Code: `Ctrl+Shift+H` (Windows) or `Cmd+Shift+H` (Mac), scope to `sql/`.

---

## Step 7 — Run the SQL pipeline in order

Execute each file in the BigQuery console (or `bq query --use_legacy_sql=false < file.sql`). Run them in this exact order:

```
sql/02_staging/stg_carriers.sql        ← filters to TX, derives size buckets
sql/02_staging/stg_crashes.sql         ← parses dates, classifies severity
sql/02_staging/stg_inspections.sql     ← derives OOS flags, violation counts
```

Run **Section 2** of `validation_pipeline.sql`. Check the outputs noted in that file before continuing.

```
sql/03_mart/mart_carrier_profile.sql       ← one row per carrier, dimensions only
sql/03_mart/mart_carrier_kpis.sql          ← crash + inspection KPIs by carrier-year
sql/03_mart/mart_industry_benchmarks.sql   ← TX medians + percentiles by year + bucket
sql/03_mart/mart_outliers.sql              ← top/bottom decile flags per size bucket
```

Run **Sections 3 and 4** of `validation_pipeline.sql`. Run **Section 5** (named-carrier spot checks) last.

```
sql/04_dashboard/vw_dashboard_benchmark.sql
sql/04_dashboard/vw_dashboard_outliers.sql
sql/04_dashboard/vw_dashboard_trends.sql
```

No validation queries needed for views — they are thin selects over the mart layer.

---

## Step 8 — Connect Tableau

1. Open Tableau Desktop or Tableau Public.
2. Connect → Google BigQuery → sign in with the same Google account as your GCP project.
3. Select your project → `fmcsa` dataset.
4. For each dashboard view, add a data source:
   - View 1 → `vw_dashboard_benchmark`
   - View 2 → `vw_dashboard_outliers`
   - View 3 → `vw_dashboard_trends_benchmarks` and `vw_dashboard_trends_heatmap`
5. Build views per `sql/04_dashboard/` and Section 4 of the project plan.

> **Tableau Public limitation:** Live BigQuery connections are not supported on Tableau Public (free). Export each view to CSV from BigQuery and connect to the CSVs instead. The `.twbx` packaged workbook bundles the data so the published dashboard works for anyone.

---

## Approximate runtimes

| Step | Time |
|---|---|
| Download + extract FMCSA files | 5–10 min |
| BigQuery setup + raw load | 5–10 min |
| Header verification + SQL edits | 10 min |
| Staging SQL | 2–3 min |
| Mart SQL | 3–5 min |
| Validation queries | 10–15 min |
| **Total** | **~45 min** |

---

## If something breaks

1. Check the field-name mapping table in Step 2 first — this causes ~80% of first-run errors.
2. Check `data_quality_log.md` for known issues documented during EDA.
3. The validation queries in `sql/00_validation/validation_pipeline.sql` are designed to surface the most common problems. Run the relevant section before assuming the pipeline is broken.
