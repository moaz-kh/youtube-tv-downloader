# Summary: YouTube videos with no sound on the TV (USB playback)

## The problem

Four videos downloaded from YouTube (`1.mp4`–`4.mp4`) were copied to a USB stick to play on an LG TV.
Only `3.mp4` played with sound. The other three showed an error like *"this video does not support audio"*.

## Diagnosis

Each file was inspected with `ffprobe`:

| File  | Video          | Audio              |
|-------|----------------|--------------------|
| 1.mp4 | H.264, 1280×720 | **none**           |
| 2.mp4 | H.264, 854×480  | **none**           |
| 3.mp4 | H.264, 640×360  | AAC (HE-AAC), stereo ✅ |
| 4.mp4 | H.264, 1280×720 | **none**           |

**The TV was not the problem.** Files 1, 2 and 4 contain **no audio track at all**. They are video-only.

## Root cause

YouTube stores its higher-quality versions (480p, 720p and up) as **separate video and audio streams**.
Only low-quality versions, like 360p, are offered as one file with both. The downloader that was used
saved only the video stream for the 480p/720p videos and never added the audio. The 360p file
(`3.mp4`) was a combined file, so it had sound.

Converting the silent files can't help, because the audio isn't in them. They must be downloaded again.

## The fix

Download with **yt-dlp**, which fetches the video and audio streams and joins them with **ffmpeg** into
one MP4. Choose codecs the TV supports, the same as the working `3.mp4`: **H.264 video + AAC audio**.

```
yt-dlp -f "bv*[vcodec^=avc1][height<=1080]+ba[acodec^=mp4a]/b[ext=mp4]" --merge-output-format mp4 "VIDEO_URL"
```

- `bv*[vcodec^=avc1][height<=1080]`: best H.264 video up to 1080p
- `+ba[acodec^=mp4a]`: plus the best AAC audio, merged together
- `/b[ext=mp4]`: fallback: the best single MP4 that already has both
- `--merge-output-format mp4`: the result is an `.mp4` file

Simpler alternative: in the original downloader, pick an option labelled "MP4 with audio" (or 360p)
and avoid options marked "video only" or "no audio".

## Install steps by hand (Windows, one time)

The project's `scripts/install.bat` does steps 1 to 3 for you.

1. Open **PowerShell** (Start → type `powershell` → Enter).
2. Install the tools:
   ```
   winget install yt-dlp.yt-dlp
   winget install Gyan.FFmpeg.Essentials
   ```
3. **Close PowerShell and open it again** so Windows finds the new tools.
4. Go to the video folder:
   ```
   cd "C:\Users\<you>\Downloads\Video"
   ```
   Shortcut: open the folder in File Explorer, type `powershell` in the address bar and press Enter.
5. Run the yt-dlp command above, once per video, with the real YouTube link in quotes.
6. Copy the new MP4 files to the USB stick.

## Troubleshooting

- **"winget is not recognized"**: install **App Installer** from the Microsoft Store.
- **"yt-dlp is not recognized"**: PowerShell wasn't reopened after installing.
- **Download fails with an error**: run `yt-dlp -U` to update. YouTube changes often.

## What came out of it

The fix became this project. You give it YouTube links, and its scripts download each one as a
TV-friendly MP4, then check that every file really has sound. The install scripts in `scripts/` do the
one-time setup above for you. See the [README](../README.md).
