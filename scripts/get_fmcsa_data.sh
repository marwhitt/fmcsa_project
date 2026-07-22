#!/usr/bin/env bash
# Download the three FMCSA files into data/raw/ with the filenames REPRODUCE.md Step 5 expects.
# Usage (from anywhere): bash scripts/get_fmcsa_data.sh
# Needs: curl, ~7 GB free disk. Exports stream server-side and may take a minute to start.
set -euo pipefail

STAMP="$(date +%Y%m%d)"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="$REPO_ROOT/data/raw"
mkdir -p "$OUTDIR"

dl () {
  local url="$1" out="$2"
  echo ""
  echo ">> Downloading $out"
  curl -L --compressed --retry 5 --retry-delay 15 --fail -o "$OUTDIR/$out" "$url"
}

# Motor Carrier Census Data (Company Census File): one row per carrier
dl "https://data.transportation.gov/api/views/az4n-8mr2/rows.csv?accessType=DOWNLOAD" \
   "FMCSA_CENSUS1_${STAMP}.csv"

# Large Truck and Bus Crash Data (Crash File): one row per crash involvement
dl "https://data.transportation.gov/api/views/aayw-vxb3/rows.csv?accessType=DOWNLOAD" \
   "FMCSA_CRASH_${STAMP}.csv"

# Motor Carrier Inspection Data (Vehicle Inspection File): one row per roadside inspection
dl "https://data.transportation.gov/api/views/fx4q-ay7w/rows.csv?accessType=DOWNLOAD" \
   "FMCSA_INSPECTION_${STAMP}.csv"

echo ""
echo ">> Done. Files in $OUTDIR:"
ls -lh "$OUTDIR"/*.csv
echo ""
echo ">> Row counts (including header line):"
wc -l "$OUTDIR"/*.csv
echo ""
echo ">> Snapshot date for README.md / REPRODUCE.md: $(date +%Y-%m-%d)"
