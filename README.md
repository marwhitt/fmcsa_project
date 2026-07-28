# Commercial Trucking Safety: A Carrier-Level Analysis of Crash Patterns and Risk Factors

**Data snapshot: `2026-07-27`** (download date; files `FMCSA_*_20260727.csv` in `data/raw/`, 6.5 GB total. Links and reference counts in [DOWNLOADS.md](DOWNLOADS.md); official baseline row counts come from `sql/00_validation/validation_pipeline.sql` Section 1 after loading.)

Portfolio project by Marvyn Whittaker. Stack: SQL (BigQuery) + Tableau. Data: FMCSA motor carrier safety records (MCMIS extracts).

## What this project does

Benchmarks Texas-domiciled commercial motor carriers on FMCSA-defined safety KPIs (crash rate per 100M VMT, driver and vehicle out-of-service rates, violation rates per inspection), surfaces outlier carriers within fleet-size peer groups, and tracks how those benchmarks shift over time. Framed from the perspective of a Texas fleet operator benchmarking against industry patterns. Full problem statement and design: [`fmcsa-project-plan_2.md`](fmcsa-project-plan_2.md).

## The data

Three FMCSA files, all keyed on USDOT number:

| File | Current dataset (DOT portal ID) | Grain |
|---|---|---|
| Motor Carrier Census Data | Company Census File (`az4n-8mr2`) | One row per carrier |
| Large Truck and Bus Crash Data | Crash File (`aayw-vxb3`) | One row per crash involvement |
| Motor Carrier Inspection Data | Vehicle Inspection File (`fx4q-ay7w`) | One row per roadside inspection |

The FMCSA page these files originally lived on has been retired; they are now published on the [DOT Open Data Portal](https://data.transportation.gov/) under FMCSA's [Open Data Program](https://www.fmcsa.dot.gov/registration/fmcsa-data-dissemination-program) and refresh roughly daily. The analysis locks to the snapshot date above; re-running on a different day yields slightly different numbers, which is expected and disclosed.

## Getting the data

From the repo root (about 7 GB total; raw data is gitignored and never committed):

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts\get_fmcsa_data.ps1
```

```bash
# Git Bash / WSL / macOS
bash scripts/get_fmcsa_data.sh
```

Both write into `data/raw/` with the filenames [`REPRODUCE.md`](REPRODUCE.md) expects. `fmcsa_download_kit.html` offers the same downloads as one-click links.

## Repo guide

| Path | What it is |
|---|---|
| `README.md` | This file |
| `fmcsa-project-plan_2.md` | Full project plan: problem statement, KPI definitions, SQL and dashboard design |
| `REPRODUCE.md` | Zero-to-dashboard reproduction steps (BigQuery + Tableau) |
| `DOWNLOADS.md` | Data manifest: sources, snapshot record, row counts, direct links |
| `fmcsa_download_kit.html` | One-click download page for the three files |
| `scripts/` | Download scripts (PowerShell and bash) |
| `data/raw/` | Raw CSVs land here (created by the scripts, gitignored) |
| `sql/` | Staging, mart, validation, and dashboard SQL (in progress) |
| `queries.sql`, `main.py` | Scratch/practice files |

## Known data caveats

1. Crash grain is carrier involvement, not crash: a multi-carrier crash appears once per involved carrier. Deduplicate on `crash_id` when counting crashes.
2. Census VMT (`mcs150_mileage`) is self-reported and can be stale; always pair with `mcs150_mileage_year` before computing rates.
3. The census includes active, inactive, and pending carriers (4.4M rows); filter status before profiling.
4. The inspection file is a rolling three-year window (roughly 2023-07 to 2026-07 for the 2026-07-27 snapshot; exact range from validation Section 1), so inspection-based KPIs cannot reach back to 2020. Decision (2026-07-21): crash KPIs keep the 2020-2024 analytical window; inspection KPIs (OOS rates, violation rates) use the 2023-2026 window and are always reported with their own clearly disclosed date range.
5. Full raw loads can approach BigQuery's 10 GB free-tier storage cap; drop raw tables after staging, or pre-filter via the portal API.

## Sources

- FMCSA Open Data Program: https://www.fmcsa.dot.gov/registration/fmcsa-data-dissemination-program
- DOT Open Data Portal: https://data.transportation.gov/
- MCMIS documentation (Inspection File overview): https://www.fmcsa.dot.gov/registration/mcmis-catalog-and-documentation-inspection-file-overview
