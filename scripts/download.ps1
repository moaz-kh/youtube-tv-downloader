<#
.SYNOPSIS
  Download YouTube videos as TV-friendly MP4 files (H.264 video + AAC audio in one file),
  then check that every downloaded file really has an audio track.
  Videos that are already in the output folder (same "[id].mp4" name) are skipped.

.EXAMPLE
  .\download.ps1 "https://www.youtube.com/watch?v=AAAA" "https://youtu.be/BBBB"
.EXAMPLE
  .\download.ps1 -LinksFile links.txt -OutDir "E:\" -MaxHeight 720
.EXAMPLE
  .\download.ps1        # no links: paste them one per line, empty line to start

  Videos go to the "downloads" folder of this project unless you pass -OutDir.

.NOTES
  If Windows blocks the script ("running scripts is disabled"), use download.bat instead,
  or run:  powershell -ExecutionPolicy Bypass -File .\download.ps1 <links>
#>
[CmdletBinding()]
param(
    [string]$OutDir = "",
    [int]$MaxHeight = 1080,
    [string]$LinksFile = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Urls
)

$ErrorActionPreference = "Continue"

# Default output folder: "downloads" next to the scripts folder. Worked out here, not in param(),
# because $PSScriptRoot is empty inside param() in Windows PowerShell.
if (-not $OutDir) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $OutDir = Join-Path (Split-Path -Parent $scriptDir) "downloads"
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# ---- 1. Check the tools are installed ---------------------------------------
$missing = @()
foreach ($tool in "yt-dlp", "ffmpeg", "ffprobe") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool }
}
if ($missing.Count -gt 0) {
    Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install them once by double-clicking install.bat (or running .\install.ps1),"
    Write-Host "then CLOSE and REOPEN PowerShell and run this script again."
    exit 1
}

# ---- 2. Collect the links ---------------------------------------------------
$list = New-Object System.Collections.Generic.List[string]
foreach ($u in $Urls) { if ($u -and $u.Trim()) { $list.Add($u.Trim()) } }

if ($LinksFile) {
    if (-not (Test-Path -LiteralPath $LinksFile)) {
        Write-Host "Links file not found: $LinksFile" -ForegroundColor Red; exit 1
    }
    foreach ($line in Get-Content -LiteralPath $LinksFile -Encoding UTF8) {
        $t = $line.Trim()
        if ($t -and -not $t.StartsWith("#")) { $list.Add($t) }
    }
}

if ($list.Count -eq 0) {
    Write-Host "Paste YouTube links, one per line. Press Enter on an empty line to start:"
    while ($true) {
        $line = Read-Host
        if (-not $line -or -not $line.Trim()) { break }
        $list.Add($line.Trim())
    }
}
if ($list.Count -eq 0) { Write-Host "No links given." -ForegroundColor Red; exit 1 }

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

# ---- 3. Download ------------------------------------------------------------
# 1. H.264 (avc1) video + AAC (mp4a) audio merged into MP4: what almost every TV plays.
# 2. H.264 video + any audio: keeps the resolution, the check below warns if the audio isn't AAC.
# 3. A single-file MP4 that already has both (often only 360p), then any single-file MP4.
$format = "bv*[vcodec^=avc1][height<=$MaxHeight]+ba[acodec^=mp4a]/bv*[vcodec^=avc1][height<=$MaxHeight]+ba/b[ext=mp4][height<=$MaxHeight]/b[ext=mp4]"
$doneList = [System.IO.Path]::GetTempFileName()
$failed = @()
$skipped = @()

$i = 0
foreach ($url in $list) {
    $i++
    Write-Host ""
    Write-Host "[$i/$($list.Count)] $url" -ForegroundColor Cyan

    # Skip the link if "<title> [<id>].mp4" is already in the output folder.
    $vid = (& yt-dlp --no-playlist --print id $url 2>$null | Select-Object -First 1)
    if ($vid) {
        $existing = Get-ChildItem -LiteralPath $OutDir -File -Filter "*.mp4" |
            Where-Object { $_.Name.EndsWith("[$vid].mp4") } | Select-Object -First 1
        if ($existing) {
            Write-Host "Already downloaded, skipping: $($existing.Name)" -ForegroundColor Yellow
            $skipped += $existing.Name
            continue
        }
    }
    $ytArgs = @(
        "-f", $format,
        "--merge-output-format", "mp4",
        "--no-playlist",
        "--windows-filenames",
        "--trim-filenames", "120",
        "-o", (Join-Path $OutDir "%(title)s [%(id)s].%(ext)s"),
        "--print-to-file", "after_move:filepath", $doneList,
        $url
    )
    & yt-dlp @ytArgs
    if ($LASTEXITCODE -ne 0) { $failed += $url }
}

# ---- 4. Verify every file has sound -----------------------------------------
Write-Host ""
Write-Host "================ Result ================"
$ok = 0; $noAudio = 0; $warn = 0
foreach ($f in Get-Content -LiteralPath $doneList -Encoding UTF8) {
    if (-not $f -or -not (Test-Path -LiteralPath $f)) { continue }
    $vInfo = (& ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,height -of csv=p=0 "$f" | Select-Object -First 1)
    $v, $h = "$vInfo".Split(",")
    $a = (& ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f" | Select-Object -First 1)
    $name = Split-Path -Leaf $f
    if (-not $a) {
        Write-Host ("NO AUDIO  {0} {1}p  {2}" -f $v, $h, $name) -ForegroundColor Red; $noAudio++
    } elseif ($a -ne "aac" -or $v -ne "h264") {
        Write-Host ("WARN      {0} {1}p + {2}  {3}" -f $v, $h, $a, $name) -ForegroundColor Yellow
        Write-Host '          TV may not play this codec. Fix: ffmpeg -i "in.mp4" -c:v copy -c:a aac -b:a 192k "out.mp4"'
        $warn++
    } else {
        Write-Host ("OK        {0} {1}p + {2}  {3}" -f $v, $h, $a, $name) -ForegroundColor Green; $ok++
    }
}
foreach ($n in $skipped) { Write-Host "SKIPPED   $n" -ForegroundColor Yellow }
foreach ($u in $failed) { Write-Host "FAILED    $u" -ForegroundColor Red }
Remove-Item -LiteralPath $doneList -ErrorAction SilentlyContinue

Write-Host "----------------------------------------"
Write-Host "OK: $ok   Warnings: $warn   No sound: $noAudio   Skipped: $($skipped.Count)   Failed: $($failed.Count)"
Write-Host "Folder: $OutDir"
if ($failed.Count -gt 0) {
    Write-Host "Tip: if downloads fail, update yt-dlp first:  yt-dlp -U   (or: winget upgrade yt-dlp.yt-dlp)" -ForegroundColor Yellow
}
if ($failed.Count -gt 0 -or $noAudio -gt 0) { exit 1 } else { exit 0 }
