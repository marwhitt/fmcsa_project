# Commercial Trucking Safety: A Carrier-Level Analysis of Crash Patterns and Risk Factors

*Portfolio project plan by Marvyn Whittaker*
*Stack: SQL + Tableau | Data: FMCSA Motor Carrier Safety | Timeline: 3 weekends + weekday sessions*

---

## 1. Problem Statement & Business Question

**Perspective and headline question.** This project is framed from the perspective of a Texas-headquartered fleet operator seeking to benchmark its safety performance against industry patterns and identify the operational behaviors that drive better, or worse, outcomes than peers.

> *Which Texas-domiciled carriers show unusually high or low observed safety outcomes after normalizing for fleet size and activity, and what measurable carrier characteristics are associated with those patterns?*

This breaks down into three analytical questions the dashboard must answer:

1. **Ranking.** Where do Texas-domiciled carriers fall on the key safety KPIs that matter to fleet operations?
2. **Outliers.** Which carriers show unusually low or unusually high observed safety outcomes within their peer group, and what carrier-level characteristics are associated with each pattern?
3. **Trends.** How have these benchmarks shifted over the past five years, and what does that suggest for an operator planning forward?

**Why this matters.** Fleet operators today lack a public, repeatable way to benchmark themselves against peers using consistent definitions. Internal metrics are easy to measure; external context is hard to find. This project builds that context from public FMCSA data.

**Outlier framing and an honest data limit.** "Outlier" here means a carrier whose observed outcomes fall well outside the peer-group distribution, in either direction. Low-rate outliers and high-rate outliers are surfaced for further investigation, not characterized as "good" or "bad." Public FMCSA data shows observed outcomes; it does not reveal the internal practices that produced them. Causal claims about what makes a carrier safer or less safe are explicitly out of scope. One important data limit: FMCSA's public crash file is reported at the carrier level, not the driver level, so carrier-level violation and inspection data serves as the proxy for behavioral signal.

**KPIs in scope (FMCSA-defined).**
- Crash rate per 100 million vehicle miles traveled (VMT)
- Driver and vehicle out-of-service (OOS) rates from roadside inspections
- Violation rate per inspection, by category (hours-of-service, maintenance, hazmat, etc.)
- Fatal- and injury-crash share as a percentage of total crashes
- Year-over-year change for each of the above

**Scope.** Texas-domiciled commercial motor carriers, freight and passenger configurations, with a five-year analytical window covering 2020 through 2024. Table- and field-level scoping is defined in Section 2.

**Definition of done.** A working operator should be able to load the dashboard, locate themselves (or a hypothetical fleet) on the benchmark, see how outlier carriers differ on observable characteristics, and walk away with three concrete things to investigate further. From a portfolio standpoint, the project is "done" when a hiring manager can read the README in under five minutes, open the dashboard, and conclude: *this person can gather data, wrangle it cleanly in SQL, surface non-obvious patterns, and present them in a way an operator could actually use.* The question itself is shaped by direct operational experience tracking PM compliance, investigating recurring failure modes, and managing shop KPIs at fleet maintenance facilities.

---

## 2. Dataset & Scope

**Source.** All data comes from the FMCSA Open Data Program (DataHub), the public-facing arm of the agency's Motor Carrier Management Information System (MCMIS). Three files are used:

- **Company Census File:** one record per carrier, including USDOT number, legal and DBA name, domicile state, power-unit count, driver count, operating status, interstate/intrastate flag, hazmat authorization, and self-reported VMT.
- **Crash File:** one record per commercial vehicle involved in a reportable crash; roughly 59 fields covering crash location, date, severity (fatal / injury / towaway), weather, road condition, vehicle configuration, and the carrier's USDOT number.
- **Inspection File:** one record per roadside inspection, with the carrier's USDOT number, inspection date, level, out-of-service outcomes (driver and vehicle), and violation codes.

All three join on `USDOT_NUMBER`, which is the spine of the analysis.

**Time window.** Five years, calendar 2020 through 2024. 2025 data is excluded because FMCSA flags it as provisional for 22 months after the snapshot date. Pre-2020 data is excluded to keep the window operationally recent.

**Snapshot date.** FMCSA refreshes daily. The project locks to a single download snapshot, documented at the top of the README. Anyone re-running on a different day will see slightly different numbers, expected and disclosed.

**Carrier inclusion.** No exclusions at the dataset level, every Texas-domiciled carrier present in the snapshot is included:

- Active and inactive carriers (inactive carriers still have valid historical crashes)
- Interstate and intrastate (Texas regulates both populations differently; both belong)
- No minimum power-unit count (one-truck owner-operators are part of the industry reality)

Each becomes a filterable dimension in the dashboard, letting an operator slice to whatever peer set matches their own profile.

**Normalization.** Comparing a 10-truck fleet to a 1,000-truck fleet without normalizing produces nonsense. Two complementary denominators are used:

- **Crashes per 100 million vehicle miles traveled (VMT):** industry-standard rate, primary benchmark. Source: carrier-reported VMT in the Company Census File.
- **Crashes per power unit:** fallback for carriers with missing or zero reported VMT. Cruder but more reliable in coverage.

The dashboard displays both, with the data-quality caveat surfaced inline so a viewer knows when each is appropriate.

**SQL platform.** BigQuery on Google Cloud's free tier. The total data volume sits well under both the 10 GB free storage cap and the 1 TB monthly query allowance, so the project costs $0 to build and to re-run.

**Reproducibility guide.** The repo includes a `REPRODUCE.md` companion file with explicit steps: download links for each FMCSA file, the snapshot date used, schema definitions, BigQuery dataset and table creation commands, `bq load` invocations for each CSV, and the SQL files in the order they should be run. Someone cloning the repo with a GCP account should be able to recreate the analytical tables in under 30 minutes.

**Data dictionary.** A `data_dictionary.md` file documents every field used from every source file: source table, field name, type, definition, and any transformations applied. Fields not used are listed separately for completeness.

**No auxiliary datasets in v1.** The project stays inside FMCSA's three core files. Bringing in NHTSA recalls, BTS VMT benchmarks, weather data, or carrier financials is captured as a stretch goal in Section 7.

**Approximate scale.** Order of magnitude: tens of thousands of carriers, tens of thousands of crash records, hundreds of thousands of inspection records. Large enough to require real query thinking, small enough that no sampling is needed. Exact volumes are confirmed at the start of Weekend 1 during the initial data pull.

---

## 3. Methodology: SQL Pipeline & Analysis

The analytical work runs as a four-layer SQL pipeline in BigQuery, with each layer having a single, well-defined job. This structure mirrors how modern data teams organize transformation work and makes the project auditable from raw input to dashboard output.

### Pipeline architecture

**Layer 1: Raw.** Three tables loaded directly from the FMCSA CSV downloads with no transformation: `raw_census`, `raw_crashes`, `raw_inspections`. Purpose: any reviewer can audit forward from the source files.

**Layer 2: Staging.** One staging table per raw table: `stg_carriers`, `stg_crashes`, `stg_inspections`. Transformations applied at this layer:
- Cast types (string-to-integer, string-to-date)
- Parse and standardize dates
- Standardize state codes to uppercase two-letter
- Trim whitespace and normalize casing on name fields
- Filter to Texas-domiciled carriers
- Filter to the 2020 through 2024 window
- Deduplicate where source files contain known duplicates

No joins and no business logic happen at this layer.

**Layer 3: Mart.** The analytical tables that hold all business logic and derived metrics. Four mart tables:
- `mart_carrier_profile`: one row per carrier with size bucket, hazmat flag, operating-status flag, interstate/intrastate flag, and other dimensions used for slicing.
- `mart_carrier_kpis`: one row per carrier per year, with crash rate per 100M VMT, crashes per power unit, driver and vehicle out-of-service rates, violation rate per inspection, fatal-crash share, and year-over-year change for each metric.
- `mart_industry_benchmarks`: industry-wide aggregates by year and carrier-size bucket. This is the comparator the operator benchmarks against.
- `mart_outliers`: flagged top-decile and bottom-decile carriers within each size bucket, joined to the operational characteristics that distinguish them.

**Layer 4: Dashboard.** Thin views over the mart layer, shaped specifically for how Tableau queries them: `vw_dashboard_benchmark`, `vw_dashboard_outliers`, `vw_dashboard_trends`. Most are near-direct selects from the mart with light reshaping for Tableau's preferred row-per-mark structure.

### SQL techniques deliberately showcased

Each technique appears in at least one transformation, with comments in the SQL files explaining the choice:

- **Common Table Expressions (CTEs)** for readability in multi-step transformations from staging to mart
- **Window functions** for year-over-year change calculations, percentile ranking within size buckets, and peer-average comparisons
- **CASE expressions** for size bucketing, severity classification, and violation categorization
- **LEFT JOINs with explicit NULL handling** so carriers with no crashes or no inspections still appear in the profile table (their absence is itself information)
- **QUALIFY clause** (BigQuery feature) for filtering on window-function results without subqueries, demonstrating modern SQL fluency
- **Date arithmetic** using `DATE_DIFF` and `DATE_TRUNC` for time-series analysis

### Analytical decisions

**Crash event vs. crash involvement.** The FMCSA Crash File has one row per commercial-vehicle involvement in a reportable crash, not one row per crash event. When two commercial vehicles are involved in the same crash, two rows exist. All metrics in this project count *crash involvements*, not unique crash events, and are labeled that way in the dashboard and data dictionary.

**Denominator decision.** Choosing a fair exposure denominator is the most consequential analytical decision in this project, and the FMCSA Census VMT field has known limitations: it is self-reported, coverage is uneven, and (depending on the snapshot's structure) may represent latest-reported VMT rather than year-specific VMT. The project uses three denominators side by side, with which one is in play disclosed inline:

| Metric | Denominator | When used | Caveat |
|---|---|---|---|
| Crash involvement rate per 100M VMT | Reported VMT | Primary exposure-normalized view | Reliable only where VMT is reasonably year-aligned; treated as approximate otherwise |
| Crashes per power unit | Power-unit count | Fallback where VMT is missing or zero | Crude proxy; ignores miles driven per truck |
| Crash involvements per inspection | Inspection count | Operational-exposure proxy for comparison | Reflects enforcement contact frequency, not miles |

The VMT-based metric is the primary headline number on the dashboard; the power-unit-based fallback is shown alongside it so a viewer sees the comparison directly and understands when each is appropriate.

**Metric definitions.** Every metric used in the project is defined here and reproduced in `data_dictionary.md`:

| Metric | Formula | Unit | Better direction | Caveat |
|---|---|---|---|---|
| Crash involvement rate | crash involvements ÷ VMT × 100,000,000 | per 100M VMT | Lower | Depends on VMT data quality |
| Crashes per power unit | crash involvements ÷ power units | ratio | Lower | Crude exposure proxy |
| Driver out-of-service rate | driver OOS inspections ÷ total inspections | percent | Lower | Inspection mix matters |
| Vehicle out-of-service rate | vehicle OOS inspections ÷ total inspections | percent | Lower | Inspection mix matters |
| Violation rate | total violations ÷ total inspections | violations per inspection | Lower | Reflects inspection intensity |
| Fatal-crash share | fatal crash involvements ÷ total crash involvements | percent | Lower | Volatile at small carrier sizes |

**Outlier definition: percentile-based, neutrally labeled.** Outliers are carriers in the top 10% or bottom 10% of a KPI within their size bucket, calculated using BigQuery's `PERCENT_RANK()` window function. They are labeled by direction of the metric, not by judgment:

- **Low-rate outlier:** carrier in the bottom 10% of the KPI distribution within its peer group (lower is better for all KPIs in this project)
- **High-rate outlier:** carrier in the top 10%

The dashboard surfaces these carriers for further investigation; it does not characterize them as safer or less safe in any absolute sense.

**Small-carrier noise: minimum threshold for outlier flagging.** A one-truck carrier with one crash has a crash rate that looks catastrophic but is not statistically meaningful. Carriers are only eligible for outlier flagging if they meet a minimum activity threshold: at least 5 power units AND at least 100,000 reported VMT in the year being evaluated. Smaller carriers remain visible in the dashboard but are excluded from outlier labels, with the rule disclosed inline.

### What is intentionally not included

To keep the project shippable in three weekends without sacrificing the core demonstration, the following are out of scope and listed in Section 7 as stretch goals or limitations:
- Formal automated data-quality testing scripts (known issues documented in the README and data dictionary instead)
- Unit tests on SQL transformations
- dbt for orchestration (the layered structure achieves the same readability without the setup overhead)
- Composite multi-KPI outlier scoring (percentile-per-KPI is sufficient for v1)

---

## 4. Tableau Dashboard Design

The deliverable is published on Tableau Public as **three connected views**, each answering one of the analytical questions from Section 1. A single mega-dashboard would force every chart to compete for attention; splitting into focused views forces a clear point of view per screen and signals deliberate design choice. Navigation is handled by a tab strip at the top of the workbook.

### Design principles applied throughout

- **Sentence-style chart titles.** Every chart is titled with the finding, not the metric. "Mid-sized fleets show the highest median crash rates" rather than "Crash Rate by Size Bucket." The chart confirms the headline.
- **Color used purposefully.** A colorblind-safe palette built around two intentional accents: blue (#2E75B6) for "better than peers" and orange (#E47C2D) for "worse than peers." Everything else stays in neutral grays so the meaningful color earns attention.
- **No pie charts.** Bars and dots only for categorical comparison.
- **Source line on every view.** "Data: FMCSA Open Data Program, snapshot [date]. Built by Marvyn Whittaker." Bottom-right, small text, consistent placement.
- **Sized for 1366 × 768.** Tableau's standard desktop sizing; no responsive mobile design.
- **Shared filters.** Year, size bucket, hazmat flag, and interstate/intrastate flag apply across all three views so filtering carries between them.

### View 1: Benchmark View (landing page)

Answers: *"Where does my fleet stand vs. industry?"*

The view a fleet operator hits first. Goal: a viewer can locate themselves on the industry distribution within ten seconds.

- **Top strip.** Four large KPI tiles showing the Texas-industry median for the four headline metrics: crash rate per 100M VMT, driver out-of-service rate, vehicle out-of-service rate, and fatal-crash share. One number each, large and bold.
- **Main chart.** A box-and-whisker plot of crash-rate distribution across all Texas carriers, split by size bucket. Box shows the interquartile range; whiskers show the 10th and 90th percentiles. An operator visually maps where their own fleet would land.
- **Side panel.** Shared filter controls (year, size bucket, hazmat, interstate/intrastate).
- **Bottom strip.** A ranked horizontal bar chart showing the lowest-rate and highest-rate carriers (by name) within the currently filtered size bucket. A persistent caption underneath reads: *Rates are based on reportable crash involvements and available exposure data. Use as a screening benchmark, not as a safety rating.*

### View 2: Outlier View

Answers: *"Who are the best and worst performers, and what do they have in common?"*

For the operator who has seen the benchmark and now wants to understand the carrier-level characteristics that distinguish low-rate from high-rate outliers.

- **Top chart.** A scatter plot. X-axis: crash involvement rate per 100M VMT. Y-axis: vehicle out-of-service rate. Dot size: power-unit count. Low-rate and high-rate outliers (bottom and top deciles within size bucket) highlighted in the two accent colors; everyone else in light gray. Tooltips reveal carrier name, USDOT, and the underlying metric values, plus the same screening-vs-rating caveat that appears in the Benchmark view.
- **Comparison panel.** Two side-by-side cards comparing the characteristics of the low-rate outlier cluster vs. the high-rate outlier cluster: average power-unit count, share interstate vs. intrastate, share hazmat-authorized, average violation rate per inspection, average years in operation.
- **Outlier table.** A sortable table of all currently flagged outlier carriers (name, USDOT, size bucket, outlier direction, each key metric) so a viewer can drill into individual carriers.

### View 3: Trends View

Answers: *"How has the industry shifted over five years, and what does that mean going forward?"*

- **Top row.** Four small-multiple line charts (one per headline KPI), each showing the Texas industry median from 2020 through 2024 with a shaded band for the interquartile range. Shows direction and dispersion simultaneously.
- **Bottom-left.** A heatmap of year-over-year crash-rate change by size bucket and year. Green cells indicate improvement, red cells indicate deterioration. Surfaces which segments are improving and which are sliding.
- **Bottom-right.** A short text panel titled "Key trend observations" with two or three plainly stated findings, written after the views are built so they're grounded in what the data actually shows.

### Hosting and publication

The workbook is published to Tableau Public, which makes it free, link-shareable, and interactive for anyone who opens it. The README links directly to the live dashboard. The Tableau workbook file (`.twbx`) is also committed to the GitHub repo so the design itself is inspectable.

### Build sequence

Views are built in this order: Benchmark → Outlier → Trends. The Benchmark view is the most important to land correctly (it is what hiring managers will spend the most time examining) and the Trends view is the most expendable if Weekend 3 runs tight.

### Explicitly out of scope

- Geographic map of Texas crash density, Texas geography does not meaningfully advance the operator-benchmark story and consumes screen real estate better used elsewhere.
- "Explorer" mode with unlimited drill-down, high build cost, low actual usage.
- Animated transitions, distracting, do not aid comprehension.
- Standalone splash/landing page inside Tableau, the README serves that role.

---

## 5. Deliverables & Repo Structure

Three deliverables, ordered by how much attention they will actually receive from a hiring manager:

1. **`README.md`:** the front door. Sells the project, shows the headline finding, links to the dashboard. Most reviewers read this and nothing else.
2. **Live Tableau Public dashboard:** the interactive deliverable. Must stand on its own with no narration.
3. **Supporting artifacts:** clean SQL, reproducible setup, data dictionary. Probably never opened by most reviewers, but professional and ready if they are.

### Repo structure

```
fmcsa-trucking-safety/
├── README.md
├── REPRODUCE.md
├── data_dictionary.md
├── LICENSE
├── .gitignore
│
├── data/
│   ├── raw/                    # gitignored; CSVs downloaded per REPRODUCE.md
│   └── README.md               # data sourcing notes
│
├── sql/
│   ├── 00_validation/          # row counts, null rates, join coverage, sanity checks
│   ├── 01_raw/                 # CREATE TABLE statements for raw layer
│   ├── 02_staging/             # raw → staging transformations
│   ├── 03_mart/                # staging → mart transformations
│   └── 04_dashboard/           # mart → dashboard view definitions
│
├── tableau/
│   ├── fmcsa_safety.twbx       # packaged workbook
│   └── screenshots/            # PNGs of each view, for README embedding
│
└── images/                     # diagrams and other embedded visuals
```

**Three structural choices worth noting:**

- **Numbered SQL folders** (`00_validation`, `01_raw`, `02_staging`, `03_mart`, `04_dashboard`) make the execution order obvious. Anyone cloning the repo knows to run them in numeric order. This is standard pattern for layered SQL pipelines and signals familiarity with how production analytics is organized.
- **Validation folder is its own layer.** `sql/00_validation/` contains short, focused SQL files that verify the pipeline produced what was expected: row counts before and after filters, distinct USDOT counts by table, null and zero rates for VMT, duplicate-record checks, join coverage between carrier / crash / inspection tables, inspection counts by year, and manual sanity checks on 5 named carriers. These are not automated tests; they are auditable proof that the work was checked.
- **Raw data files are gitignored, not committed.** FMCSA CSVs would inflate the repo to hundreds of MB, slow down clones, potentially hit GitHub's 100 MB file size limit, and freeze a stale data snapshot into the repo permanently. Instead, `REPRODUCE.md` provides download links, the snapshot date, and the BigQuery load commands. This is standard practice for data projects.

### README structure

```
# Commercial Trucking Safety: Carrier-Level Benchmarking in Texas

## TL;DR
[2-3 sentences: question, method, headline finding]

## Live Dashboard
[Embedded screenshot → click-through to Tableau Public]

## How to Review This Project in 5 Minutes
1. Read the TL;DR.
2. Open the Tableau dashboard (link above).
3. Skim the Benchmark view; note the screening-vs-rating caveat.
4. Open `sql/03_mart/mart_carrier_kpis.sql` to see the metric logic.
5. Open `sql/00_validation/metric_sanity_checks.sql` to see how the work was checked.

## The Question
[Operator perspective; three sub-questions]

## Data
[FMCSA, three files, Texas 2020-2024, snapshot date]

## Metric Definitions
[Compact version of the metric table from Section 3]

## Key Findings
[3-5 bullets, the actual insights from the analysis]

## Tools
[BigQuery | Tableau | Git]

## Repo Structure
[Tree from above, with one-line descriptions]

## Reproducing This Analysis
[Brief intro → link to REPRODUCE.md]

## Limitations & Notes
[2-3 honest bullets, including the no-causal-claims line]

## About
[1-2 lines, link to LinkedIn]
```

The README is written last, after the dashboard is built and findings are known. Lead with the finding, not the methodology. Keep it to roughly two screens of scroll.

### REPRODUCE.md

Separated from the README so the README stays scannable. Contents:

- FMCSA download URLs for each source file
- The snapshot date used in this analysis
- GCP and BigQuery project/dataset setup commands
- `bq load` commands for each CSV
- SQL execution order (run `sql/01_raw/` files first, then `02_staging/`, etc.)
- How to open the `.twbx` Tableau workbook
- Approximate runtime per step

Target: a reviewer with a GCP account can recreate the analytical tables from scratch in roughly 30 minutes.

### data_dictionary.md

A single reference file documenting:

- Every field used from each source file: source table, field name, data type, definition, source-documentation link
- Every derived metric in the mart layer: metric name, formula, units, interpretation

Fields not used in the analysis are listed in a final section for completeness.

### Explicitly out of scope

- `requirements.txt` / `environment.yml`, no Python dependencies in v1
- Makefile or orchestration scripts, adds complexity disproportionate to project size
- GitHub Actions or CI, out of scope
- Issues, project boards, or wikis, will not be read
- Blog post / Medium write-up / LinkedIn post, separately valuable, listed as a stretch goal in Section 7

---

## 6. Timeline & Milestones

**Working schedule.** Days off are Monday and Tuesday, used as the primary "weekend" build blocks (roughly 8 hours each). Weekday sessions land on Thursday and Saturday evenings after the morning job, roughly 2 hours each. Total budget: approximately 33 hours across three weeks of execution, with planning and scoping already completed in Week 0.

| Phase | Time on task | Cumulative |
|---|---|---|
| Week 0 (planning + study guide) | done | done |
| Week 1 | 12 hours | 12 |
| Week 2 | 12 hours | 24 |
| Week 3 | 12 hours | 36 |

### Week 0. Planning and refresher (complete)

Project plan drafted across seven sections. SQL Study Guide built as a refresher reference. Dataset, scope, methodology, dashboard structure, and repo layout locked in before any code is written.

### Week 1. Foundation, raw and staging layers

**Monday and Tuesday (~8 hours)**
- Download FMCSA Census, Crash, and Inspection files; record snapshot date
- Create GCP project, BigQuery dataset, billing alert set at $1
- Load all three CSVs into `raw_` tables using `bq load`
- Write and run all `sql/01_raw/` table creation files
- Write and run `sql/02_staging/` transformations: cast types, parse dates, filter to Texas-domiciled carriers and 2020 through 2024 window, deduplicate
- Spot-check row counts and basic distributions against expectations
- Initialize the GitHub repo and commit raw + staging work

**Thursday (~2 hours)**
- Begin `sql/03_mart/` work on `mart_carrier_profile`: carrier identity, size buckets, operating-status and hazmat flags

**Saturday (~2 hours)**
- Begin `mart_carrier_kpis`: join crashes and inspections to the carrier profile, calculate base aggregations (counts, sums)

**End-of-week deliverable:** raw + staging tables built and validated; mart layer in progress.

### Week 2. Analytical heart, mart layer and dashboard scaffolding

**Monday and Tuesday (~8 hours)**
- Finish `mart_carrier_kpis`: rate calculations (per 100M VMT, per power unit), year-over-year change via `LAG` window function
- Build `mart_industry_benchmarks`: medians and interquartile ranges by size bucket and year
- Build `mart_outliers`: `PERCENT_RANK` partitioned by size bucket and year, with minimum activity threshold (>= 5 power units AND >= 100k VMT), filtered with `QUALIFY`
- Validation pass: spot-check several known large carriers, confirm aggregate medians look plausible against any findable published industry numbers
- Open Tableau, connect to BigQuery, wire up data sources for the three dashboard views
- Build skeleton versions of all three views (charts present, data flowing, no polish yet)

**Thursday (~2 hours)**
- Polish the Benchmark view: KPI tiles, box-and-whisker formatting, ranked bar chart at the bottom

**Saturday (~2 hours)**
- Apply consistent chart titles, color palette, and source-line treatment across the Benchmark view

**End-of-week deliverable:** full SQL pipeline complete; Benchmark view polished; Outlier and Trends views built but not yet polished.

### Week 3. Polish, narrative, ship

**Monday and Tuesday (~8 hours)**
- Polish the Outlier view: scatter plot with conditional coloring, side-by-side comparison panels, sortable outlier table
- Build and polish the Trends view: small-multiple line charts with interquartile bands, YoY change heatmap, key-observations text panel
- Publish workbook to Tableau Public; verify it renders correctly when accessed from a logged-out browser
- Take clean screenshots of each view for README embedding
- Write `data_dictionary.md`
- Write `REPRODUCE.md`
- Write `README.md` last, now that findings are known and can be led with
- Final commit and push to GitHub

**Thursday (~2 hours)**
- Buffer for bug fixes, link verification, and review
- Ask a peer to clone the repo and attempt reproduction; capture any friction points

**Saturday (~2 hours)**
- Optional LinkedIn post announcing the project, if ready
- Final review pass on README phrasing, image quality, and dashboard polish

**End-of-week deliverable:** live dashboard, polished README, reproducible repo.

### Built-in cut points

The timeline is realistic but tight. If any phase runs long, the following cuts preserve a shippable project:

- **End of Week 2, mart layer behind schedule:** drop the `PERCENT_RANK` outlier classification and fall back to a simple top-10 / bottom-10 ranking. Loses sophistication; preserves the rest of the project.
- **End of Week 3 Monday, Trends view not started:** cut it entirely. Ship a polished two-view dashboard rather than a sloppy three. Update the README and Section 4 to reflect what shipped.
- **Week 3 Tuesday, forced choice between dashboard polish and README:** README wins, every time. A clean README pointing to a functional-but-rough dashboard outperforms a beautiful dashboard paired with a thrown-together README.

---

## 7. Limitations & Stretch Goals

### Limitations

Four caveats a thoughtful reviewer should know about. Each is built into the data or scope, not a flaw in the analysis.

**Observed outcomes only; no causal claims.** The analysis surfaces patterns in publicly reported outcomes. It does not, and cannot, identify the internal practices, training programs, equipment choices, or management decisions that produced those outcomes. A carrier appearing as a low-rate outlier is not characterized as "safer than" peers, and a high-rate outlier is not characterized as "less safe than" peers. Both are surfaced for further investigation.

**Driver-level data is not public.** FMCSA strips driver names and identifiers from the public Crash File for privacy. Behavioral patterns in this analysis are inferred from carrier-level violation and inspection data, which serves as a proxy for operational discipline. Direct attribution to specific drivers or driver behaviors is out of scope.

**VMT is self-reported and coverage is uneven.** Vehicle miles traveled, the denominator for the primary crash-rate metric, is reported by carriers and validated inconsistently. Carriers with missing VMT fall back to crashes-per-power-unit normalization, which is cruder but more reliably present. The dashboard surfaces which denominator is in use so a viewer knows what they are reading.

**The Crash File captures reportable crashes only.** Federal reporting thresholds require a fatality, an injury treated away from scene, or a vehicle towed from scene. Minor incidents that do not meet these thresholds are not in the data. "Crash rate" throughout this analysis is more precisely "reportable crash rate."

**Numbers reflect a single snapshot date.** FMCSA refreshes daily. The figures here are accurate as of the snapshot date documented in the README. Re-running the same analysis at a later date will produce slightly different numbers as historical records are amended or backfilled.

### Stretch goals

Four directions a v2 of this project could take. Each is deliberately deferred to keep v1 focused and shippable.

**Predictive modeling layer.** A natural follow-up using Python and a model like logistic regression to predict whether a carrier will have a fatal crash in year N+1 from year-N features (size, prior crash history, OOS rates, violation patterns). Complements the SQL and Tableau work by adding a Python dimension and a forward-looking question.

**Auxiliary data joins.** Bringing in NHTSA recalls (vehicle-defect angle), BTS VMT statistics (more comprehensive denominators), or NOAA weather data (crash-condition analysis) would deepen the analytical surface significantly.

**Blog or Medium write-up of findings.** A separately valuable artifact for portfolio reach: a 5-to-10-minute read that walks a non-technical audience through the headline findings, with screenshots and a link to the live dashboard.

**LinkedIn announcement post.** A short post sharing the dashboard link and headline finding, written after launch. Aimed at amplifying the project's reach into fleet, logistics, and insurance hiring circles.
