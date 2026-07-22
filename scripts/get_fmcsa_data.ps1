# Download the three FMCSA files into data\raw\ with the filenames REPRODUCE.md Step 5 expects.
# Usage (from the repo root): powershell -ExecutionPolicy Bypass -File scripts\get_fmcsa_data.ps1
# Needs: Windows 10+ (ships curl.exe), ~7 GB free disk. Exports may take a minute to start.
$ErrorActionPreference = "Stop"

$stamp    = Get-Date -Format "yyyyMMdd"
$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir   = Join-Path $repoRoot "data\raw"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$files = @(
    @{ Name = "FMCSA_CENSUS1_$stamp.csv"
       Url  = "https://data.transportation.gov/api/views/az4n-8mr2/rows.csv?accessType=DOWNLOAD" },  # census: one row per carrier
    @{ Name = "FMCSA_CRASH_$stamp.csv"
       Url  = "https://data.transportation.gov/api/views/aayw-vxb3/rows.csv?accessType=DOWNLOAD" },  # crash: one row per involvement
    @{ Name = "FMCSA_INSPECTION_$stamp.csv"
       Url  = "https://data.transportation.gov/api/views/fx4q-ay7w/rows.csv?accessType=DOWNLOAD" }   # inspection: one row per inspection
)

foreach ($f in $files) {
    $out = Join-Path $outDir $f.Name
    Write-Host ""
    Write-Host ">> Downloading $($f.Name)"
    & curl.exe -L --compressed --retry 5 --retry-delay 15 --fail -o $out $f.Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $($f.Name) (curl exit $LASTEXITCODE)" }
}

Write-Host ""
Write-Host ">> Done. Files in $outDir :"
Get-ChildItem $outDir -Filter *.csv |
    Format-Table Name, @{ n = "SizeMB"; e = { [math]::Round($_.Length / 1MB, 1) } }

Write-Host ">> Snapshot date for README.md / REPRODUCE.md: $(Get-Date -Format 'yyyy-MM-dd')"
