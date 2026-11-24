<#
.SYNOPSIS
  Install what the downloader needs on Windows: yt-dlp and ffmpeg (ffprobe comes with ffmpeg).
  Uses winget. Safe to run again: it skips what is installed and tries to update it.
  If a tool is installed but does not run (a broken link), it reinstalls it once.

.EXAMPLE
  .\install.ps1

.NOTES
  If Windows blocks the script ("running scripts is disabled"), use install.bat instead,
  or run:  powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
$ErrorActionPreference = "Continue"

function Test-Tool([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# Make tools installed a moment ago visible in this window without reopening PowerShell.
function Update-SessionPath {
    $machine = [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable("Path", "Machine"))
    $user = [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable("Path", "User"))
    $env:Path = "$machine;$user;$env:Path"
}

# Returns the first line of the tool's version output, or $null if the tool cannot run.
function Get-ToolVersion([string]$Tool) {
    try {
        if ($Tool -eq "yt-dlp") { $out = & $Tool --version 2>&1 } else { $out = & $Tool -version 2>&1 }
        if ($LASTEXITCODE -ne 0) { return $null }
        return "$($out | Select-Object -First 1)"
    } catch {
        return $null
    }
}

if (-not (Test-Tool "winget")) {
    Write-Host "winget was not found." -ForegroundColor Red
    Write-Host "Install 'App Installer' from the Microsoft Store, then run this again."
    exit 1
}

# Tool name -> winget package that provides it.
# ffmpeg uses the "Essentials" build (about 80 MB); the "full" build is 250+ MB and not needed here.
$packageFor = @{ "yt-dlp" = "yt-dlp.yt-dlp"; "ffmpeg" = "Gyan.FFmpeg.Essentials"; "ffprobe" = "Gyan.FFmpeg.Essentials" }

foreach ($tool in "yt-dlp", "ffmpeg") {
    $id = $packageFor[$tool]
    if (Get-ToolVersion $tool) {
        Write-Host "${tool}: already installed, checking for an update..."
        winget upgrade --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        # Someone who installed the full ffmpeg build earlier keeps it, and it is updated here.
        if ($tool -eq "ffmpeg") {
            winget upgrade --id "Gyan.FFmpeg" -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        }
    } else {
        Write-Host "Installing $tool..."
        winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    }
}
Update-SessionPath

# ---- Check, and repair once -------------------------------------------------
# A tool counts as OK only if it really runs, not just if PowerShell can find it.
function Show-Check {
    $broken = @()
    Write-Host ""
    Write-Host "================ Check ================"
    foreach ($tool in "yt-dlp", "ffmpeg", "ffprobe") {
        $v = Get-ToolVersion $tool
        if ($v) {
            Write-Host ("OK       {0}  {1}" -f $tool, $v) -ForegroundColor Green
        } elseif (Test-Tool $tool) {
            $path = (Get-Command $tool -ErrorAction SilentlyContinue | Select-Object -First 1).Source
            Write-Host ("BROKEN   {0}  found at {1} but it does not run" -f $tool, $path) -ForegroundColor Red
            $broken += $tool
        } else {
            Write-Host ("MISSING  {0}" -f $tool) -ForegroundColor Red
            $broken += $tool
        }
    }
    return $broken
}

$broken = @(Show-Check)
if ($broken.Count -gt 0) {
    Write-Host ""
    Write-Host "Reinstalling the packages that do not work..." -ForegroundColor Yellow
    foreach ($id in ($broken | ForEach-Object { $packageFor[$_] } | Select-Object -Unique)) {
        winget install --id $id -e --force --silent --accept-package-agreements --accept-source-agreements
    }
    Update-SessionPath
    $broken = @(Show-Check)
}

if (-not (Test-Tool "deno") -and -not (Test-Tool "node") -and -not (Test-Tool "bun")) {
    Write-Host ""
    Write-Host "Note: recent yt-dlp versions may need a JavaScript runtime (deno or node) to read YouTube."
    Write-Host "If downloads fail with a warning about a JavaScript runtime, install one:  winget install DenoLand.Deno"
}

Write-Host ""
if ($broken.Count -gt 0) {
    Write-Host "Still not working: $($broken -join ', ')" -ForegroundColor Red
    Write-Host "Close PowerShell, open it again, and run this script once more."
    Write-Host "If it still fails, see Troubleshooting in the README."
    exit 1
}
Write-Host "Ready. Next: double-click download.bat, or run .\download.ps1 ""https://www.youtube.com/watch?v=..."""
Write-Host "If a new window says 'yt-dlp is not recognized', close it and open a fresh one."
exit 0
