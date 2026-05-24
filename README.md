# BatchDownloader

BatchDownloader is a minimal native macOS app for batch downloading social media video and audio with `yt-dlp` and `ffmpeg`.

The app is designed for a simple workflow:

1. Paste one or more links, one per line.
2. Choose whether those links should be downloaded as video or audio.
3. Pick a download folder with Browse.
4. Start the batch.

## What It Is For

This MVP is for quickly downloading media from popular websites supported by `yt-dlp`, especially when collecting multiple links before starting a batch. It prioritizes compatibility and usability over advanced download controls.

## Hardcoded Formats

The download settings are intentionally hardcoded:

- Video downloads prefer original H.264 MP4 when available.
- If the final video is not H.264, the app transcodes it to H.264 MP4 with `ffmpeg`.
- Audio downloads are always extracted as MP3 at 320 kbps.

There are no user-facing codec, container, bitrate, or quality settings. This keeps the app straightforward and produces files that are broadly compatible with media players, editors, and sharing workflows.

## Requirements

- macOS 14 or newer
- Swift toolchain for building from source
- `yt-dlp` installed at `/opt/homebrew/bin/yt-dlp`
- `ffmpeg` installed at `/opt/homebrew/bin/ffmpeg`

The current build assumes Homebrew-style Apple Silicon paths for `yt-dlp` and `ffmpeg`.

## Build And Run

Use the project script:

```bash
./script/build_and_run.sh
```

To build, launch, and verify the running process:

```bash
./script/build_and_run.sh --verify
```

The script stages a native app bundle at:

```text
dist/BatchDownloader.app
```

## Limitations

- Download behavior depends on `yt-dlp` support for each website.
- Some sites may require cookies, login, or additional `yt-dlp` options that this MVP does not expose.
- The app does not provide per-link quality controls.
- The app does not currently show detailed progress percentages per item.
- Dependency paths are hardcoded to `/opt/homebrew/bin`.
- Playlist downloading is disabled; the app expects direct media links.
