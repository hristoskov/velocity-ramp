[CmdletBinding()]
param(
    [string]$DepsDir,
    [string]$BaseUrl = "https://download.cppmodel.com/",
    [ValidateSet("UCRT64", "CLANG64", "MSVC")]
    [string]$Platform
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $DepsDir) { $DepsDir = Join-Path $ProjectRoot "dependencies" }

if (-not $Platform) {
    $found = @()
    foreach ($exe in "g++", "clang++") {
        $cmd = Get-Command $exe -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -match "(?i)ucrt64") { $found += "UCRT64" }
        elseif ($cmd -and $cmd.Source -match "(?i)clang64") { $found += "CLANG64" }
    }
    if (Get-Command cl -ErrorAction SilentlyContinue) { $found += "MSVC" }
    $found = @($found | Select-Object -Unique)

    if ($found.Count -eq 1) { $Platform = $found[0] }
    elseif ($found.Count -eq 0) { throw "Could not detect Windows toolchain. Pass -Platform UCRT64|CLANG64|MSVC." }
    else { throw "Multiple toolchains detected ($($found -join ', ')). Pass -Platform to disambiguate." }
}

$archiveName = "CppModel-latest-Windows-$Platform.zip"
Write-Host "Target platform: Windows-$Platform"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "cppmodel-install-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Path $tempDir | Out-Null
$archivePath = Join-Path $tempDir $archiveName
Write-Host "Downloading $archiveName ..."
Invoke-WebRequest -Uri ($BaseUrl + $archiveName) -OutFile $archivePath -UseBasicParsing

$stagingRoot = Join-Path $tempDir "staging"
Write-Host "Extracting..."
Expand-Archive -Path $archivePath -DestinationPath $stagingRoot -Force
$versionDir = Get-ChildItem $stagingRoot -Directory | Select-Object -First 1

if (Test-Path $DepsDir) { Remove-Item $DepsDir -Recurse -Force }
Move-Item $versionDir.FullName $DepsDir
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Installed CppModel $($versionDir.Name -replace '^CppModel-', '') into $DepsDir"
