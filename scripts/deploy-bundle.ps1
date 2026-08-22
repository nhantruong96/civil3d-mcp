<#
.SYNOPSIS
  Builds the Civil 3D plugin and deploys it as an autoload bundle.

.DESCRIPTION
  Copies the build output plus PackageContents.xml into
  %APPDATA%\Autodesk\ApplicationPlugins\Civil3dMcp.bundle so Civil 3D loads
  the plugin on startup (no NETLOAD needed). Civil 3D must be closed.

.PARAMETER Configuration
  Build configuration to deploy. Default: Release.

.PARAMETER SkipBuild
  Deploy the existing build output without rebuilding.
#>
param(
  [string]$Configuration = 'Release',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$projectDir = Join-Path $repoRoot 'plugin\Civil3dMcpPlugin'
$bundleSrc  = Join-Path $repoRoot 'plugin\bundle\PackageContents.xml'
$bundleDir  = Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\Civil3dMcp.bundle'
$contents   = Join-Path $bundleDir 'Contents'

$acadRunning = [bool](Get-Process -Name 'acad' -ErrorAction SilentlyContinue)
if ($acadRunning) {
  Write-Warning 'Civil 3D is running. The bundle only takes effect after a restart, and the copy will fail if the plugin is already loaded in that session.'
}

if (-not $SkipBuild) {
  Write-Host "Building $Configuration..."
  & dotnet build $projectDir -c $Configuration
  if ($LASTEXITCODE -ne 0) { throw "dotnet build failed with exit code $LASTEXITCODE" }
}

# Resolve the single TFM output folder (net10.0-windows today, net8.0-windows for C3D 2025 and 2026).
$binDir = Join-Path $projectDir "bin\$Configuration"
$outDir = Get-ChildItem -Path $binDir -Directory | Select-Object -First 1
if (-not $outDir) { throw "No build output under $binDir" }

if (Test-Path $contents) { Remove-Item $contents -Recurse -Force }
New-Item -ItemType Directory -Path $contents -Force | Out-Null

Copy-Item -Path (Join-Path $outDir.FullName '*') -Destination $contents -Recurse -Force
Remove-Item (Join-Path $contents '*.pdb') -Force -ErrorAction SilentlyContinue
Copy-Item -Path $bundleSrc -Destination (Join-Path $bundleDir 'PackageContents.xml') -Force

Write-Host "Deployed to $bundleDir"
if ($acadRunning) {
  Write-Host 'Restart Civil 3D, then run C3DMCPSTATUS to verify the listener.'
} else {
  Write-Host 'Start Civil 3D and run C3DMCPSTATUS to verify the listener.'
}
