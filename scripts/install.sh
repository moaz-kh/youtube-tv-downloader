#!/usr/bin/env bash
# Install what the downloader needs: yt-dlp and ffmpeg (ffprobe comes with ffmpeg).
# Works on Linux (apt, dnf, pacman, zypper, apk) and macOS (Homebrew).
# Safe to run again: it skips what is already installed and tries to update yt-dlp.
#
# Usage:
#   ./install.sh        (uses sudo for ffmpeg on Linux, so it may ask for your password)

set -u

have() { command -v "$1" >/dev/null 2>&1; }
say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Run a command as root (directly if already root, otherwise through sudo).
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    die "need root to install packages, but sudo is not available. Run this script as root."
  fi
}

OS="$(uname -s)"
ARCH="$(uname -m)"

# ---- ffmpeg -----------------------------------------------------------------
install_ffmpeg() {
  if have ffmpeg && have ffprobe; then
    say "ffmpeg: already installed"
    return 0
  fi
  say "Installing ffmpeg..."
  if [ "$OS" = "Darwin" ]; then
    have brew || die "Homebrew is needed on macOS. Install it from https://brew.sh and run this again."
    brew install ffmpeg
  elif have apt-get; then
    as_root apt-get update && as_root apt-get install -y ffmpeg
  elif have dnf; then
    as_root dnf install -y ffmpeg-free || as_root dnf install -y ffmpeg
  elif have pacman; then
    as_root pacman -S --noconfirm ffmpeg
  elif have zypper; then
    as_root zypper --non-interactive install ffmpeg
  elif have apk; then
    as_root apk add ffmpeg
  else
    die "no supported package manager found. Install ffmpeg yourself: https://ffmpeg.org/download.html"
  fi
}

# ---- yt-dlp -----------------------------------------------------------------
# On Linux, distro packages of yt-dlp are often old and YouTube changes often, so
# this downloads the official release into ~/.local/bin. macOS uses Homebrew.
install_ytdlp() {
  if have yt-dlp; then
    say "yt-dlp: already installed ($(yt-dlp --version)), checking for an update..."
    yt-dlp -U || say "  Could not self-update. Update it with the tool you installed it with."
    return 0
  fi
  say "Installing yt-dlp..."
  if [ "$OS" = "Darwin" ]; then
    have brew || die "Homebrew is needed on macOS. Install it from https://brew.sh and run this again."
    brew install yt-dlp
    return 0
  fi

  local asset
  case "$ARCH" in
    x86_64)          asset="yt-dlp_linux" ;;
    aarch64|arm64)   asset="yt-dlp_linux_aarch64" ;;
    *)               asset="yt-dlp" ;;   # python script, needs python3
  esac
  if [ "$asset" = "yt-dlp" ] && ! have python3; then
    die "no ready-made yt-dlp for $ARCH and python3 is missing. Install python3, then run this again."
  fi

  local url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/$asset"
  local dest="$HOME/.local/bin"
  local tmp
  mkdir -p "$dest" || die "cannot create $dest"
  tmp="$(mktemp)"
  if have curl; then
    curl -fL --progress-bar -o "$tmp" "$url" || { rm -f "$tmp"; die "download failed: $url"; }
  elif have wget; then
    wget -O "$tmp" "$url" || { rm -f "$tmp"; die "download failed: $url"; }
  else
    rm -f "$tmp"
    die "need curl or wget to download yt-dlp."
  fi
  chmod +x "$tmp"
  mv "$tmp" "$dest/yt-dlp" || die "cannot write $dest/yt-dlp"
  say "yt-dlp installed to $dest/yt-dlp"
}

install_ffmpeg
install_ytdlp

# ~/.local/bin is not on PATH in every setup.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH"
     say ""
     say "Note: $HOME/.local/bin is not on your PATH. Add this line to ~/.bashrc (or ~/.zshrc):"
     say "  export PATH=\"\$HOME/.local/bin:\$PATH\""
     ;;
esac

# ---- Check ------------------------------------------------------------------
say ""
say "================ Check ================"
missing=0
for tool in yt-dlp ffmpeg ffprobe; do
  if have "$tool"; then
    case "$tool" in
      yt-dlp) v="$(yt-dlp --version)" ;;
      *)      v="$("$tool" -version | head -n1)" ;;
    esac
    say "OK       $tool  $v"
  else
    say "MISSING  $tool"
    missing=1
  fi
done

if ! have deno && ! have node && ! have bun; then
  say ""
  say "Note: recent yt-dlp versions may need a JavaScript runtime (deno or node) to read YouTube."
  say "If downloads fail with a warning about a JavaScript runtime, install one:"
  say "  https://deno.com  or  https://nodejs.org"
fi

if [ "$missing" -ne 0 ]; then
  say ""
  say "Something is missing. Read the messages above."
  exit 1
fi
say ""
say "Ready. Next: bash scripts/download.sh \"https://www.youtube.com/watch?v=...\""
