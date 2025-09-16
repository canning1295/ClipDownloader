# ClipDownloader

ClipDownloader is a macOS desktop app for trimming clips from individual YouTube videos. Paste a video URL, choose a start and end time, pick quality/container options, and save the finished clip locally using bundled `yt-dlp` and `ffmpeg` helpers.

## Highlights

- **Single-window SwiftUI interface** focused on one clip at a time
- **Flexible time entry** accepting `SS`, `MM:SS`, or `HH:MM:SS`
- **Quality & container controls** (Auto ≤1080p, 1080p, 720p, 480p and MP4/WebM/Audio-only)
- **Accuracy modes** for frame-accurate exports or fast keyframe trims
- **Filename templating** with tokens rendered into the final filename
- **Console & progress feedback** that surfaces `yt-dlp`/`ffmpeg` status and cancellation

## System Requirements

- macOS 15.0 or newer (Apple silicon recommended)
- Internet connection for downloading the source video
- Local disk space for temporary downloads and output clips

## Project Structure

```
ClipDownloader/
├── ClipDownloaderApp.swift        # @main entry point
├── Models/                        # Data model & validation helpers
├── Services/                      # yt-dlp/ffmpeg orchestration & toolchain
├── Views/                         # SwiftUI screens and panels
├── ViewModels/                    # MVVM state management
├── Resources/
│   └── bin/                       # Bundled yt-dlp & ffmpeg binaries
├── ClipDownloader.entitlements    # Hardened runtime entitlements
├── PROJECT_CONFIG.md              # Xcode project reference settings
└── README.md                      # This file
```

## Building the App

1. **Bundle the helper binaries**
   ```bash
   cd ClipDownloader/Resources/bin

   # Download yt-dlp universal binary
   curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o yt-dlp
   chmod +x yt-dlp

   # Obtain an ffmpeg universal2 build (LGPL components)
   # Extract the ffmpeg binary into this directory and mark it executable
   chmod +x ffmpeg
   ```

2. **Open the project in Xcode**
   - Open `ClipDownloader.xcodeproj`
   - Set the signing team and enable the Hardened Runtime
   - Ensure `ClipDownloader.entitlements` is attached to the main target

3. **Run & iterate**
   - Build and run on macOS 15+
   - Verify that the app downloads and trims a clip end-to-end using the bundled tools

4. **Prepare for distribution**
   - Archive the `ClipDownloader` scheme
   - Export with Developer ID signing
   - Notarize the resulting app bundle

## Usage Flow

1. Paste a YouTube URL into the Source panel.
2. Enter start/end timestamps in any supported format.
3. Select desired quality, container, and accuracy mode.
4. (Optional) Adjust advanced options such as download sections or bitrates.
5. Choose an output folder (defaults to `~/Downloads/ClipDownloader/`).
6. Review the live filename preview and click **Download Clip**.
7. Watch progress as the job downloads, trims, and encodes; cancel if necessary.
8. Reveal the completed clip in Finder from the success toast.

## Filename Tokens

Filename templates can include the following placeholders:

| Token        | Description                                 |
|--------------|---------------------------------------------|
| `{title}`    | Original YouTube title                       |
| `{id}`       | YouTube video ID                             |
| `{start}`    | Normalized start timestamp (`HH-MM-SS`)      |
| `{end}`      | Normalized end timestamp (`HH-MM-SS`)        |
| `{res}`      | Selected output resolution                   |
| `{container}`| Final container/extension (`mp4`, `webm`, …) |

Default template: `{title}_{start}-{end}.{container}`

## Legal & Compliance Notes

ClipDownloader is intended for personal use with content you are authorized to download. Respect YouTube's Terms of Service, applicable copyright laws, and redistribute outputs responsibly.

For license obligations of bundled binaries, include the appropriate notices for `yt-dlp` and `ffmpeg` in the final app bundle.

## Roadmap (Out of Scope for v1)

- Clip preview playback inside the app
- Queuing multiple clips for batch processing
- Metadata export sidecars (CSV/JSON)
- Localization and accessibility refinements beyond VoiceOver basics

For configuration specifics such as code signing scripts and Info.plist keys, see [PROJECT_CONFIG.md](./PROJECT_CONFIG.md).
