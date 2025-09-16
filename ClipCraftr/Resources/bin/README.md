# Binary Bundle Instructions

This directory should contain the following universal binaries for macOS:

## Required Binaries

1. **yt-dlp** - YouTube downloader
   - Download from: https://github.com/yt-dlp/yt-dlp/releases
   - Get the macOS binary: yt-dlp_macos
   - Rename to: yt-dlp
   - Make executable: chmod +x yt-dlp

2. **ffmpeg** - Video processing tool
   - Download from: https://ffmpeg.org/download.html#build-mac
   - Get the universal binary (Intel + Apple Silicon)
   - Extract ffmpeg binary from archive
   - Rename to: ffmpeg
   - Make executable: chmod +x ffmpeg

## Build Script

You can use the following script to download and prepare the binaries:

```bash
#!/bin/bash
cd ClipCraftr/Resources/bin

# Download yt-dlp
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o yt-dlp
chmod +x yt-dlp

# Download ffmpeg (you'll need to adapt this URL to the latest version)
# curl -L [ffmpeg-download-url] -o ffmpeg.tar.xz
# tar -xf ffmpeg.tar.xz
# mv ffmpeg-*/bin/ffmpeg ./ffmpeg
# chmod +x ffmpeg
# rm -rf ffmpeg-* ffmpeg.tar.xz

echo "Binaries prepared for bundling"
```

## Code Signing

The binaries will be code signed as part of the app bundle during the build process.
The Xcode project should be configured with:

1. Build Phase: "Copy Bundle Resources" includes bin/ directory
2. Build Phase: "Run Script" to sign embedded binaries
3. Hardened Runtime enabled
4. Entitlements for process execution

## Size Considerations

- yt-dlp: ~20-30 MB
- ffmpeg: ~60-80 MB
- Total binary payload: ~100 MB

This is acceptable for a desktop application focused on video processing.

## Testing

Before building for distribution, test that both binaries work:

```bash
./yt-dlp --version
./ffmpeg -version
```

Both should output version information without errors.