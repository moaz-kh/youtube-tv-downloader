#!/usr/bin/env bash
# Show the video/audio codecs of video files. Flags files with NO audio track, and
# files whose codecs are not H.264 + AAC (some TVs cannot play those).
# Usage: ./check_audio.sh [FOLDER_OR_FILE ...]     (default: current folder)
set -u
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found. Run: bash scripts/install.sh" >&2; exit 1; }
[ "$#" -eq 0 ] && set -- .

bad=0
check() {
  local f="$1" v a
  v="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,height -of csv=p=0 "$f" | head -n1)"
  a="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f" | head -n1)"
  if [ -z "$a" ]; then
    printf 'NO AUDIO  video=%-12s audio=-      %s\n' "${v:-?}" "$f"; bad=$((bad + 1))
  elif [ "$a" != "aac" ] || [ "${v%%,*}" != "h264" ]; then
    printf 'WARN      video=%-12s audio=%-6s %s\n' "${v:-?}" "$a" "$f"
    echo "          TV may not play this codec. Fix: ffmpeg -i \"in.mp4\" -c:v copy -c:a aac -b:a 192k \"out.mp4\""
  else
    printf 'OK        video=%-12s audio=%-6s %s\n' "${v:-?}" "$a" "$f"
  fi
}

for p in "$@"; do
  if [ -d "$p" ]; then
    while IFS= read -r -d '' f; do check "$f"; done < <(
      find "$p" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' \) -print0 | sort -z)
  elif [ -f "$p" ]; then
    check "$p"
  else
    echo "Not found: $p" >&2
  fi
done
[ "$bad" -eq 0 ]
