#!/usr/bin/env bash
# Download YouTube videos as TV-friendly MP4 files (H.264 video + AAC audio in one file),
# then check that every downloaded file really has an audio track.
# Videos that are already in the output folder (same "[id].mp4" name) are skipped.
#
# Usage:
#   ./download.sh URL [URL ...]
#   ./download.sh -f links.txt
#   ./download.sh -o "/path/to/USB" -q 720 URL ...
#   ./download.sh            (no arguments: paste links one per line, empty line to start)
#
# Options:
#   -o DIR   folder to save videos in (default: the "downloads" folder of this project)
#   -q N     maximum video height: 360, 480, 720, 1080 (default: 1080)
#   -f FILE  text file with one link per line (lines starting with # are ignored)
#   -h       show this help

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/../downloads"
MAX_HEIGHT=1080
LINKS_FILE=""

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

while getopts ":o:q:f:h" opt; do
  case "$opt" in
    o) OUT_DIR="$OPTARG" ;;
    q) MAX_HEIGHT="$OPTARG" ;;
    f) LINKS_FILE="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Option -$OPTARG needs a value" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

case "$MAX_HEIGHT" in ''|*[!0-9]*) echo "-q must be a number like 720" >&2; exit 2 ;; esac

# ---- 1. Check the tools are installed ---------------------------------------
missing=0
for tool in yt-dlp ffmpeg ffprobe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing: $tool" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  cat >&2 <<'EOF'

Install the missing tools first:
  Linux / macOS:  bash scripts/install.sh
  Windows:        use download.bat / download.ps1 and install.bat / install.ps1 instead
EOF
  exit 1
fi

# ---- 2. Collect the links ---------------------------------------------------
urls=()
for u in "$@"; do [ -n "$u" ] && urls+=("$u"); done

if [ -n "$LINKS_FILE" ]; then
  if [ ! -f "$LINKS_FILE" ]; then echo "Links file not found: $LINKS_FILE" >&2; exit 1; fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$line" in ''|'#'*) continue ;; esac
    urls+=("$line")
  done < "$LINKS_FILE"
fi

if [ "${#urls[@]}" -eq 0 ]; then
  echo "Paste YouTube links, one per line. Press Enter on an empty line to start:"
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$line" ] && break
    urls+=("$line")
  done
fi

if [ "${#urls[@]}" -eq 0 ]; then echo "No links given." >&2; exit 1; fi

mkdir -p "$OUT_DIR" || { echo "Cannot create folder: $OUT_DIR" >&2; exit 1; }

# ---- 3. Download ------------------------------------------------------------
# 1. H.264 (avc1) video + AAC (mp4a) audio merged into MP4: what almost every TV plays.
# 2. H.264 video + any audio: keeps the resolution, the check below warns if the audio isn't AAC.
# 3. A single-file MP4 that already has both (often only 360p), then any single-file MP4.
FORMAT="bv*[vcodec^=avc1][height<=${MAX_HEIGHT}]+ba[acodec^=mp4a]/bv*[vcodec^=avc1][height<=${MAX_HEIGHT}]+ba/b[ext=mp4][height<=${MAX_HEIGHT}]/b[ext=mp4]"

done_list="$(mktemp)"
trap 'rm -f "$done_list"' EXIT
failed=()
skipped=()

i=0
for url in "${urls[@]}"; do
  i=$((i + 1))
  echo
  echo "[$i/${#urls[@]}] $url"

  # Skip the link if "<title> [<id>].mp4" is already in the output folder.
  vid="$(yt-dlp --no-playlist --print id "$url" 2>/dev/null | head -n1)"
  if [ -n "$vid" ]; then
    existing="$(find "$OUT_DIR" -maxdepth 1 -type f -name "*\[$vid\].mp4" -print -quit)"
    if [ -n "$existing" ]; then
      echo "Already downloaded, skipping: $(basename "$existing")"
      skipped+=("$existing")
      continue
    fi
  fi

  if ! yt-dlp \
      -f "$FORMAT" \
      --merge-output-format mp4 \
      --no-playlist \
      --windows-filenames \
      --trim-filenames 120 \
      -o "${OUT_DIR}/%(title)s [%(id)s].%(ext)s" \
      --print-to-file "after_move:filepath" "$done_list" \
      "$url"; then
    failed+=("$url")
  fi
done

# ---- 4. Verify every file has sound -----------------------------------------
echo
echo "================ Result ================"
no_audio=0
ok=0
warn=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  IFS=, read -r v h < <(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,height -of csv=p=0 "$f" | head -n1)
  a="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f" | head -n1)"
  name="$(basename "$f")"
  if [ -z "$a" ]; then
    echo "NO AUDIO  ${v:-?} ${h:-?}p  $name"
    no_audio=$((no_audio + 1))
  elif [ "$a" != "aac" ] || [ "${v:-}" != "h264" ]; then
    echo "WARN      ${v:-?} ${h:-?}p + ${a}  $name"
    echo "          TV may not play this codec. Fix: ffmpeg -i \"in.mp4\" -c:v copy -c:a aac -b:a 192k \"out.mp4\""
    warn=$((warn + 1))
  else
    echo "OK        ${v} ${h:-?}p + ${a}  $name"
    ok=$((ok + 1))
  fi
done < "$done_list"

for f in "${skipped[@]+"${skipped[@]}"}"; do echo "SKIPPED   $(basename "$f")"; done
for u in "${failed[@]+"${failed[@]}"}"; do echo "FAILED    $u"; done

echo "----------------------------------------"
echo "OK: $ok   Warnings: $warn   No sound: $no_audio   Skipped: ${#skipped[@]}   Failed: ${#failed[@]}"
echo "Folder: $(cd "$OUT_DIR" && pwd)"
if [ "${#failed[@]}" -gt 0 ]; then
  echo "Tip: if downloads fail, update yt-dlp first:  yt-dlp -U   (or: python3 -m pip install -U yt-dlp)"
fi

[ "${#failed[@]}" -eq 0 ] && [ "$no_audio" -eq 0 ]
