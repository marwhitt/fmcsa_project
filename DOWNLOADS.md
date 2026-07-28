# FMCSA Carrier Data: Download Manifest

## Snapshot record

**Snapshot in use: downloaded 2026-07-27** (files in `data/raw/`, verified 2026-07-28)

| File | Downloaded file | Size |
|---|---|---|
| Motor Carrier Census Data | FMCSA_CENSUS1_20260727.csv | 1.71 GB |
| Large Truck and Bus Crash Data | FMCSA_CRASH_20260727.csv | 1.86 GB |
| Motor Carrier Inspection Data | FMCSA_INSPECTION_20260727.csv | 2.91 GB |

Official row counts for this snapshot: run `sql/00_validation/validation_pipeline.sql` Section 1 after loading and record the results here.

Reference API check (2026-07-21 19:52 UTC, for context only; the portal drifts daily): census 4,437,562 rows (portal last updated 2026-07-10), crash 4,967,095 rows (max report_date 2026-07-16), inspections 8,195,106 rows (max insp_date 2026-05-19).

Provenance note: the original FMCSA page (fmcsa.dot.gov/safety/carrier-safety/carrier-data-reports) now returns 404. These files moved to the DOT Open Data Portal under FMCSA's Open Data Program and are refreshed on a rolling (approximately daily) basis, so there is no single monthly snapshot date anymore. The snapshot date for analysis is the download date recorded above.

---

## File 1: Motor Carrier Census Data

Current official name: **Company Census File**

- One row per registered entity (carrier), identified by `dot_number`
- Direct CSV download: https://data.transportation.gov/api/views/az4n-8mr2/rows.csv?accessType=DOWNLOAD
- Dataset page: https://data.transportation.gov/Trucking-and-Motorcoaches/Company-Census-File/az4n-8mr2/about_data
- API endpoint (SODA, filterable): https://data.transportation.gov/resource/az4n-8mr2.json
- Estimated uncompressed CSV size: roughly 1.5 GB
- Key fields: identity (`dot_number`, `company_officer_1`, docket numbers, phone), status (`status_code`, `carrier_operation`), fleet size (`power_units`, `truck_units`, `bus_units`, `fleetsize`, `total_drivers`, `total_cdl`), VMT (`mcs150_mileage`, `mcs150_mileage_year`), flags (`hm_ind`, `prior_revoke_flag`)
- Includes active, inactive, and pending registrations. Filter on `status_code` if you only want active carriers.

## File 2: Large Truck and Bus Crash Data

Current official name: **Crash File**

- One row per carrier/vehicle involvement in a police-reported crash (59 data elements)
- Direct CSV download: https://data.transportation.gov/api/views/aayw-vxb3/rows.csv?accessType=DOWNLOAD
- Dataset page: https://data.transportation.gov/Trucking-and-Motorcoaches/Crash-File/aayw-vxb3/about_data
- API endpoint (SODA, filterable): https://data.transportation.gov/resource/aayw-vxb3.json
- Estimated uncompressed CSV size: roughly 2 GB
- Coverage: `report_date` spans 1982-01-08 to 2026-07-16 as stored; expect sparse and possibly erroneous early dates, with the bulk of records in recent decades. Verify the distribution after download.
- Key fields: `crash_id`, `report_state`, `report_number`, `report_seq_no`, `report_date`, `dot_number`, `fatalities`, `injuries`, `tow_away`, `federal_recordable`, `state_recordable`, `truck_bus_ind`, weather/light/road condition codes, `crash_carrier_name`

## File 3: Motor Carrier Inspection Data

Current official name: **Vehicle Inspection File**

- One row per roadside inspection, identified by `inspection_id`
- Direct CSV download: https://data.transportation.gov/api/views/fx4q-ay7w/rows.csv?accessType=DOWNLOAD
- Dataset page: https://data.transportation.gov/Trucking-and-Motorcoaches/Vehicle-Inspection-File/fx4q-ay7w/about_data
- API endpoint (SODA, filterable): https://data.transportation.gov/resource/fx4q-ay7w.json
- Estimated uncompressed CSV size: roughly 3 GB
- Coverage: rolling three-year window; 2023-05-21 to 2026-05-19 at the 2026-07-21 API check (the 2026-07-27 snapshot shifts to roughly 2023-07 through 2026-07; confirm via validation Section 1)
- Key fields: `inspection_id`, `dot_number`, `insp_date`, `report_state`, `insp_level_id`, violation and out-of-service totals (`viol_total`, `oos_total`, plus driver/vehicle/hazmat breakdowns), `insp_carrier_name`
- Note: this file carries violation TOTALS per inspection. Per-violation detail lives in a separate dataset ("Vehicle Inspections and Violations") if you need it later.

---

## How to download

Any of these routes works; the export streams server-side and can take a minute to start, then downloads for a while (multi-GB files).

1. Click the three "Direct CSV download" links above in a browser (or open `fmcsa_download_kit.html`).
2. From the repo root, run `scripts\get_fmcsa_data.ps1` (Windows PowerShell) or `scripts/get_fmcsa_data.sh` (Git Bash / WSL / macOS). Both write into `data/raw/` (gitignored) with the filenames `REPRODUCE.md` Step 5 expects.
3. Use the SODA API endpoints with `$where` filters to pull only the slice you need (much smaller downloads), e.g. Texas carriers only: append `?$where=phy_state='TX'` to the census endpoint.

Documentation: FMCSA Open Data Program page (https://www.fmcsa.dot.gov/registration/fmcsa-data-dissemination-program) and the MCMIS catalog pages, e.g. the Inspection File overview (https://www.fmcsa.dot.gov/registration/mcmis-catalog-and-documentation-inspection-file-overview).
