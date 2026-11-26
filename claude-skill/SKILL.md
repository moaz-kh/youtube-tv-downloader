---
name: youtube-tv-downloader
description: Download YouTube links as TV-friendly MP4s (H.264 + AAC, with sound) and fix "audio not supported" on USB TV playback. Use when the user gives YouTube links to download or a video plays silent on a TV.
---

# YouTube → TV-friendly MP4 downloader

## Why this exists (the root cause)

YouTube serves anything above 360p as **separate video-only and audio-only streams** (DASH).
Many simple downloaders save only the video stream, so the file has **no audio track at all**.
A TV playing it from USB then says something like *"audio not supported"*. It isn't a codec the TV
can't play: there is simply no audio in the file. Re-encoding can't fix it; the video must be
downloaded again with audio merged in.

The fix: download with **yt-dlp**, which fetches both streams and merges them with **ffmpeg** into
one MP4 using codecs nearly every TV plays: **H.264 (avc1) video + AAC (mp4a) audio**.

Format rule used everywhere in this skill (`H` = max height, default 1080):
```
bv*[vcodec^=avc1][height<=H]+ba[acodec^=mp4a]/bv*[vcodec^=avc1][height<=H]+ba/b[ext=mp4][height<=H]/b[ext=mp4]
```
Order: H.264 + AAC; H.264 + any audio (keeps the resolution, the check warns if the audio isn't AAC);
a single-file MP4 (often only 360p); any single-file MP4.
Plus: `--merge-output-format mp4 --no-playlist --windows-filenames --trim-filenames 120`.

## Diagnosing existing files

When a user says a video has no sound on the TV, check the files first:
```
ffprobe -v error -show_entries stream=index,codec_type,codec_name,profile,width,height -of compact FILE
```
- No `codec_type=audio` line → no audio track → re-download (this is the usual case).
- Audio present but `opus`, `vorbis`, `ac3`/`eac3` or `dts` → the TV may not support that codec → fix
  by converting only the audio:
  `ffmpeg -i in.mp4 -c:v copy -c:a aac -b:a 192k out.mp4`
- `scripts/check_audio.sh FOLDER` / `scripts/check_audio.ps1 FOLDER` prints OK / WARN / NO AUDIO per file.
  WARN means the file has audio but the codecs aren't H.264 + AAC; it prints the ffmpeg fix.

## Workflow when the user gives links

1. **Collect the links** from the message (one or many; `youtube.com/watch?v=`, `youtu.be/`, `shorts/`).
   Ask where to save only if it isn't obvious; default is the folder the user connected or named.
   Default quality 1080; use `-q 720` / `-MaxHeight 720` if the user asks for smaller files or an older TV.
2. **If this session is linked to the user's computer and a device shell is available**, try to run the
   download there (the shell is a Linux environment with the user's folders mounted under `$HOME/mnt/`):
   - make sure the tools exist: `command -v ffmpeg ffprobe; yt-dlp --version || python3 -m pip install --user -U yt-dlp`
     (add `~/.local/bin` to `PATH` if pip installed it there)
   - write `download.sh` (from the project's `scripts/` folder, or from the Appendix below) into a scratch location,
     **not** into the user's video folder, and run it:
     `bash download.sh -o "$HOME/mnt/<folder>" -q 1080 "URL1" "URL2" ...`
   - downloads can exceed the shell's time limit per call: run one URL per call, or start it in the
     background with `nohup … > log.txt 2>&1 &` and poll the log.
   - If YouTube can't be reached from that shell (network/proxy errors), stop and use step 3.
3. **Otherwise, give the user a ready-to-paste command** with their links filled in (see "Running it
   on Windows"), and tell them to run it in PowerShell inside the folder where they want the videos.
4. **Report the result** from the script's summary: files saved with sound, any "NO AUDIO", any "SKIPPED" (already in the folder), any failures.
   On failures, the first fix is updating yt-dlp (`yt-dlp -U` / `winget upgrade yt-dlp.yt-dlp`).
5. Remind the user to copy the new MP4s to the USB stick. FAT32 sticks can't hold files over 4 GB; if a
   file is bigger, suggest `-q 720` or formatting the stick as exFAT (if the TV supports it).

Only download content the user is entitled to save (their own videos, Creative Commons, or for
personal offline viewing where YouTube's terms allow it).

## Install instructions (Windows) — one time

Double-click `scripts\install.bat` (or run `.\scripts\install.ps1` in PowerShell). It installs yt-dlp and
ffmpeg with winget and prints a check at the end. By hand, in **PowerShell**:
```
winget install yt-dlp.yt-dlp
winget install Gyan.FFmpeg.Essentials
```
Then **close PowerShell and open it again** so Windows finds the new tools. Check with:
```
yt-dlp --version
ffmpeg -version
```

### Running it on Windows

**With the project scripts** (recommended: also checks every file has sound). Videos go to the project's
`downloads\` folder unless `-OutDir` says otherwise:
```
.\scripts\download.ps1 "https://www.youtube.com/watch?v=AAAA" "https://youtu.be/BBBB"
.\scripts\download.ps1 -LinksFile links.txt -MaxHeight 720
.\scripts\download.ps1 -OutDir "E:\" "LINK"      # straight to the USB stick
```
Or double-click `scripts\download.bat` and paste the links (empty line to start).

**Without the scripts** (one video per command):
```
yt-dlp -f "bv*[vcodec^=avc1][height<=1080]+ba[acodec^=mp4a]/bv*[vcodec^=avc1][height<=1080]+ba/b[ext=mp4]" --merge-output-format mp4 "https://www.youtube.com/watch?v=XXXXXXX"
```

### Install on macOS / Linux
- Run `bash scripts/install.sh`. It uses Homebrew on macOS, and apt, dnf, pacman, zypper or apk on Linux
  for ffmpeg, and puts the latest yt-dlp release in `~/.local/bin` on Linux.
- Then: `bash scripts/download.sh -o ~/Videos "URL1" "URL2"`

### Troubleshooting
| Symptom | Fix |
|---|---|
| `winget is not recognized` | Install **App Installer** from the Microsoft Store, then retry. |
| `yt-dlp is not recognized` | PowerShell wasn't reopened after installing. Close it and open it again. |
| `running scripts is disabled on this system` | Use `download.bat`, or `powershell -ExecutionPolicy Bypass -File .\download.ps1 <links>`. |
| Download errors (HTTP 403, "Sign in to confirm", "unable to extract") | YouTube changed something: `yt-dlp -U` (or `winget upgrade yt-dlp.yt-dlp`), then retry. |
| `ffmpeg not found` / "requested merging … but ffmpeg is not installed" | `winget install Gyan.FFmpeg.Essentials`, reopen PowerShell. |
| File still says NO AUDIO | The video has no H.264+AAC version; the script fell back to the best single MP4. Retry with `-MaxHeight 720` or `-q 360`. |
| Result says WARN (e.g. `opus`) | The file has sound but the TV may not play that codec. Run the printed `ffmpeg … -c:v copy -c:a aac` command: it only re-encodes the audio, so it takes seconds. |
| Result shows a low height such as 360p | The video had no H.264 version, so the script took a single-file MP4. Not an error, just lower quality. |
| TV says "file not supported" for a large video | Try `-q 720`; some TVs can't decode H.264 High profile at 1080p. |
| Copy to USB fails for big files | FAT32 limit is 4 GB per file: use a lower quality or an exFAT stick. |

## Project files

```
youtube-tv-downloader/
├── README.md                quick start for humans
├── LICENSE
├── links.example.txt        example links file (copy to links.txt; one URL per line, # = comment)
├── claude-skill/SKILL.md    this file
├── docs/why-no-audio.md     how the problem was diagnosed
└── scripts/
    ├── install.sh           install yt-dlp + ffmpeg on Linux/macOS
    ├── install.ps1          install yt-dlp + ffmpeg on Windows (winget)
    ├── install.bat          double-click wrapper for install.ps1
    ├── download.sh          Linux/macOS/device-shell downloader + audio check
    ├── download.ps1         Windows downloader + audio check
    ├── download.bat         double-click wrapper (bypasses script policy)
    ├── check_audio.sh       list files with/without audio (Linux/macOS)
    └── check_audio.ps1      list files with/without audio (Windows)
```
Videos are saved in `downloads/` (git-ignored) unless `-o` / `-OutDir` says otherwise.
Both downloaders: check tools → collect links (args, `links.txt`, or pasted) → download each link with
the format rule → record each saved file → run ffprobe on it → print `OK` / `WARN` / `NO AUDIO` / `FAILED`. Links whose `[id].mp4` is already in the output folder are skipped and shown as `SKIPPED`.
Exit code is non-zero if anything failed or has no audio (`WARN` alone does not fail).

## Appendix: `scripts/download.sh` (write this out if the project folder isn't available)

These appendix copies are shortened versions of the real scripts (no `WARN` check). If you change the format
rule or the check in `scripts/`, change it here too.

```bash
#!/usr/bin/env bash
# Usage: download.sh [-o DIR] [-q MAX_HEIGHT] [-f links.txt] [URL ...]
set -u
OUT_DIR="."; MAX_HEIGHT=1080; LINKS_FILE=""
while getopts ":o:q:f:" opt; do
  case "$opt" in o) OUT_DIR="$OPTARG";; q) MAX_HEIGHT="$OPTARG";; f) LINKS_FILE="$OPTARG";;
  *) echo "usage: $0 [-o DIR] [-q H] [-f FILE] URL..." >&2; exit 2;; esac
done
shift $((OPTIND - 1))
for t in yt-dlp ffmpeg ffprobe; do command -v "$t" >/dev/null || { echo "Missing: $t" >&2; exit 1; }; done
urls=(); for u in "$@"; do [ -n "$u" ] && urls+=("$u"); done
if [ -n "$LINKS_FILE" ]; then
  while IFS= read -r l || [ -n "$l" ]; do l="$(printf '%s' "$l" | tr -d '\r' | xargs)"
    case "$l" in ''|'#'*) ;; *) urls+=("$l");; esac; done < "$LINKS_FILE"
fi
[ "${#urls[@]}" -eq 0 ] && { echo "No links given." >&2; exit 1; }
mkdir -p "$OUT_DIR"
FORMAT="bv*[vcodec^=avc1][height<=${MAX_HEIGHT}]+ba[acodec^=mp4a]/bv*[vcodec^=avc1][height<=${MAX_HEIGHT}]+ba/b[ext=mp4][height<=${MAX_HEIGHT}]/b[ext=mp4]"
done_list="$(mktemp)"; trap 'rm -f "$done_list"' EXIT; failed=()
for url in "${urls[@]}"; do
  echo; echo ">> $url"
  yt-dlp -f "$FORMAT" --merge-output-format mp4 --no-playlist --windows-filenames --trim-filenames 120 \
    -o "${OUT_DIR}/%(title)s [%(id)s].%(ext)s" --print-to-file "after_move:filepath" "$done_list" "$url" \
    || failed+=("$url")
done
echo; echo "===== Result ====="; bad=0
while IFS= read -r f; do [ -f "$f" ] || continue
  a="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f" | head -n1)"
  if [ -z "$a" ]; then echo "NO AUDIO  $(basename "$f")"; bad=$((bad+1)); else echo "OK ($a)  $(basename "$f")"; fi
done < "$done_list"
for u in "${failed[@]+"${failed[@]}"}"; do echo "FAILED    $u"; done
[ "${#failed[@]}" -eq 0 ] && [ "$bad" -eq 0 ]
```

## Appendix: `scripts/download.ps1` (short version, for Windows)

```powershell
param([string]$OutDir = (Get-Location).Path, [int]$MaxHeight = 1080, [string]$LinksFile = "",
      [Parameter(ValueFromRemainingArguments = $true)][string[]]$Urls)
foreach ($t in "yt-dlp","ffmpeg","ffprobe") { if (-not (Get-Command $t -EA SilentlyContinue)) {
  Write-Host "Missing $t. Run: winget install yt-dlp.yt-dlp ; winget install Gyan.FFmpeg.Essentials ; then reopen PowerShell"; exit 1 } }
$list = @($Urls | Where-Object { $_ -and $_.Trim() })
if ($LinksFile) { $list += Get-Content $LinksFile -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") } }
if (-not $list) { Write-Host "No links given."; exit 1 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$format = "bv*[vcodec^=avc1][height<=$MaxHeight]+ba[acodec^=mp4a]/bv*[vcodec^=avc1][height<=$MaxHeight]+ba/b[ext=mp4][height<=$MaxHeight]/b[ext=mp4]"
$done = [IO.Path]::GetTempFileName(); $failed = @()
foreach ($url in $list) {
  Write-Host "`n>> $url"
  & yt-dlp -f $format --merge-output-format mp4 --no-playlist --windows-filenames --trim-filenames 120 `
    -o (Join-Path $OutDir "%(title)s [%(id)s].%(ext)s") --print-to-file "after_move:filepath" $done $url
  if ($LASTEXITCODE -ne 0) { $failed += $url }
}
Write-Host "`n===== Result ====="
foreach ($f in Get-Content $done -Encoding UTF8) { if (-not (Test-Path -LiteralPath $f)) { continue }
  $a = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f" | Select-Object -First 1
  if ($a) { Write-Host "OK ($a)  $(Split-Path -Leaf $f)" } else { Write-Host "NO AUDIO  $(Split-Path -Leaf $f)" } }
$failed | ForEach-Object { Write-Host "FAILED    $_" }
```
