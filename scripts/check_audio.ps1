<#
.SYNOPSIS
  Show the video/audio codecs of video files. Flags files with NO audio track, and files
  whose codecs are not H.264 + AAC (some TVs cannot play those).
.EXAMPLE
  .\check_audio.ps1                      # current folder
.EXAMPLE
  .\check_audio.ps1 "C:\Users\me\Downloads\Video"
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host "ffprobe not found. Run install.bat (or .\install.ps1), then reopen PowerShell" -ForegroundColor Red
    exit 1
}
if (-not $Paths) { $Paths = @((Get-Location).Path) }

$exts = ".mp4", ".mkv", ".webm", ".mov", ".avi"
$files = foreach ($p in $Paths) {
    if (Test-Path -LiteralPath $p -PathType Container) {
        Get-ChildItem -LiteralPath $p -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name
    } elseif (Test-Path -LiteralPath $p) { Get-Item -LiteralPath $p }
    else { Write-Host "Not found: $p" -ForegroundColor Yellow }
}

$bad = 0
foreach ($f in $files) {
    $v = (& ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,height -of csv=p=0 "$($f.FullName)" | Select-Object -First 1)
    $a = (& ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$($f.FullName)" | Select-Object -First 1)
    if (-not $a) {
        Write-Host ("NO AUDIO  video={0,-12} audio=-      {1}" -f $v, $f.Name) -ForegroundColor Red; $bad++
    } elseif ($a -ne "aac" -or $v.Split(",")[0] -ne "h264") {
        Write-Host ("WARN      video={0,-12} audio={1,-6} {2}" -f $v, $a, $f.Name) -ForegroundColor Yellow
        Write-Host '          TV may not play this codec. Fix: ffmpeg -i "in.mp4" -c:v copy -c:a aac -b:a 192k "out.mp4"'
    } else {
        Write-Host ("OK        video={0,-12} audio={1,-6} {2}" -f $v, $a, $f.Name) -ForegroundColor Green
    }
}
if ($bad -gt 0) { exit 1 } else { exit 0 }
