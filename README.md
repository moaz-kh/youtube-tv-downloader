# youtube-tv-downloader

Download YouTube videos as **MP4 files that play with sound on a TV from a USB stick**: H.264 video + AAC
audio, merged into one file. After each download the scripts check the file and report `OK`, `WARN`,
`NO AUDIO` or `FAILED`.

## Why

YouTube serves anything above 360p as separate video and audio streams. Many downloaders save only the
video stream, so the file has no sound at all, and the TV says something like "audio not supported".
This project uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [ffmpeg](https://ffmpeg.org) to download
both streams, merge them, and pick codecs that TVs play. Details: [docs/why-no-audio.md](docs/why-no-audio.md).

## Quick start

Get the project:
```
git clone https://github.com/moaz-kh/youtube-tv-downloader.git
cd youtube-tv-downloader
```
(or download the ZIP from GitHub and unpack it).

### Linux / macOS

```
bash scripts/install.sh                                   # once: installs ffmpeg and yt-dlp
bash scripts/download.sh "https://www.youtube.com/watch?v=AAAA" "https://youtu.be/BBBB"
```
`install.sh` uses `apt`, `dnf`, `pacman`, `zypper` or `apk` on Linux and Homebrew on macOS. It asks for
your password (sudo) to install ffmpeg. Run it again later to update yt-dlp.

### Windows

1. Double-click `scripts\install.bat` (once). It installs ffmpeg (the smaller "Essentials" build) and yt-dlp with winget.
2. Double-click `scripts\download.bat`, paste the links one per line, then press Enter on an empty line.

Or in PowerShell:
```
.\scripts\install.ps1
.\scripts\download.ps1 "https://www.youtube.com/watch?v=AAAA" "https://youtu.be/BBBB"
```
If `winget` is not found, install **App Installer** from the Microsoft Store first.

Videos are saved in the `downloads/` folder of the project. Copy them to the USB stick.

## Options

| What | Windows | Linux / macOS |
|---|---|---|
| Output folder | `-OutDir "E:\"` | `-o /media/usb` |
| Maximum height (360, 480, 720, 1080; default 1080) | `-MaxHeight 720` | `-q 720` |
| Many links from a file | `-LinksFile links.txt` | `-f links.txt` |

```
.\scripts\download.ps1 -OutDir "E:\" -MaxHeight 720 "LINK"
bash scripts/download.sh -o ~/Videos -q 720 -f links.txt
```
To use a links file, copy `links.example.txt` to `links.txt` and put one link per line. Lines starting with
`#` are ignored. In `download.bat`, put each link in double quotes if it contains `&`.

## What the check means

| Result | Meaning |
|---|---|
| `OK` | H.264 video + AAC audio. Plays on nearly every TV. |
| `WARN` | Has sound, but the codecs are not H.264 + AAC (for example Opus audio). The TV may not play it. The script prints an `ffmpeg` command that re-encodes only the audio. |
| `NO AUDIO` | The file has no audio track. Download it again. |
| `FAILED` | The download failed. See troubleshooting. |

The result also shows the video height. If it is low (such as 360p), that video had no H.264 version
at the quality you asked for.

## Check files you already have

```
.\scripts\check_audio.ps1 "C:\Users\<you>\Downloads\Video"
bash scripts/check_audio.sh ~/Videos
```
Files marked `NO AUDIO` were saved as video-only and need downloading again. Re-encoding cannot add
audio that is not there.

## Troubleshooting

| Problem | Fix |
|---|---|
| `winget is not recognized` | Install **App Installer** from the Microsoft Store |
| Install check says `BROKEN` ("found at ... but it does not run") | A winget link points to a missing file. The install script reinstalls it once. If it still fails: `winget uninstall yt-dlp.yt-dlp` / `winget uninstall Gyan.FFmpeg.Essentials`, then run the install script again |
| `yt-dlp is not recognized` after installing | Close PowerShell (or the terminal) and open it again |
| `yt-dlp: command not found` on Linux | Add `~/.local/bin` to your PATH: `export PATH="$HOME/.local/bin:$PATH"` |
| `running scripts is disabled` | Use the `.bat` files, or `powershell -ExecutionPolicy Bypass -File .\scripts\download.ps1 ...` |
| Downloads fail (HTTP 403, "Sign in to confirm", "unable to extract") | Update yt-dlp: run the install script again, or `yt-dlp -U` / `winget upgrade yt-dlp.yt-dlp` |
| Warning about a JavaScript runtime | Install deno or node: `winget install DenoLand.Deno`, or see [deno.com](https://deno.com) |
| TV says "file not supported" for a 1080p video | Try `-q 720`; some TVs cannot decode 1080p H.264 |
| Big file won't copy to USB | FAT32 allows at most 4 GB per file. Use `-q 720` or format the stick as exFAT |

## Use it as a Claude skill

[claude-skill/SKILL.md](claude-skill/SKILL.md) is a skill file for Claude. It tells Claude how to run these
scripts when you give it YouTube links, and how to diagnose a video with no sound on a TV.

## Project layout

```
scripts/        install, download and check scripts (Linux/macOS: .sh, Windows: .ps1 and .bat)
docs/           why-no-audio.md: how the problem was diagnosed
claude-skill/   SKILL.md for Claude
links.example.txt
```

## Use responsibly

Only download videos you have the right to save: your own, Creative Commons, or personal offline viewing
where YouTube's terms allow it.

## License

MIT License — Copyright (c) 2026 [moaz khaled](https://github.com/moaz-kh).

Free to use, modify, and distribute for any purpose. Attribution required — keep the copyright notice in all copies or substantial portions of the code.
