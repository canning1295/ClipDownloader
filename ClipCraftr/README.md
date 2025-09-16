# ClipCraftr

A native macOS application for creating precise video clips from YouTube videos.

## Features

- **Simple Interface**: Clean SwiftUI interface designed for macOS
- **Precise Timing**: Frame-accurate cutting with customizable accuracy modes
- **Quality Options**: Choose from multiple video quality and format options
- **Batch Processing**: Queue multiple clips (planned feature)
- **Native Integration**: Proper macOS integration with Finder, drag & drop, etc.

## System Requirements

- macOS 13.0 (Ventura) or later
- Intel or Apple Silicon Mac
- Internet connection for downloading videos

## How to Build

1. **Download Dependencies**
   ```bash
   cd ClipCraftr/Resources/bin
   
   # Download yt-dlp
   curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o yt-dlp
   chmod +x yt-dlp
   
   # Download ffmpeg (get universal binary)
   # Visit https://ffmpeg.org/download.html#build-mac
   # Extract ffmpeg binary and place in this directory
   chmod +x ffmpeg
   ```

2. **Open in Xcode**
   - Open `ClipCraftr.xcodeproj`
   - Configure code signing with your Developer ID
   - Build and run

3. **For Distribution**
   - Archive the app
   - Export for Developer ID distribution
   - Notarize with Apple
   - Distribute

## Usage

1. **Enter YouTube URL**: Paste any YouTube video URL
2. **Set Time Range**: Specify start and end times (SS, MM:SS, or HH:MM:SS format)
3. **Choose Options**: Select quality, format, and accuracy mode
4. **Set Output**: Choose output folder and filename template
5. **Download Clip**: Click "Download Clip" to start processing

## Accuracy Modes

- **Frame-accurate**: Re-encodes video for precise timing (slower, exact)
- **Keyframe-only**: Copies without re-encoding (faster, approximate timing)

## File Naming Templates

Use tokens in filename templates:
- `{title}` - Video title
- `{start}` - Start time
- `{end}` - End time
- `{res}` - Resolution
- `{container}` - File format
- `{uploader}` - Channel name
- `{date}` - Upload date
- `{id}` - Video ID

Example: `{uploader} - {title} [{res}] ({start}-{end}).{container}`

## Legal Notice

This application is for personal, non-commercial use only. Users are responsible for:
- Respecting YouTube's Terms of Service
- Adhering to copyright laws in their jurisdiction
- Obtaining necessary permissions for downloaded content
- Not redistributing copyrighted material

The developers are not responsible for any misuse of this software.

## Technical Architecture

- **Language**: Swift 5.9+
- **Framework**: SwiftUI for UI, Foundation for core logic
- **Dependencies**: Bundled yt-dlp and ffmpeg binaries
- **Architecture**: MVVM with Combine for reactive updates

### Key Components

- `JobOrchestrator`: Coordinates download and cutting workflow
- `YtDlpService`: Handles video downloading with yt-dlp
- `FFmpegService`: Handles video cutting and encoding with ffmpeg
- `FilenameTemplating`: Processes filename templates with token replacement
- `Validation`: Input validation and error checking

## Contributing

This project is part of a specification implementation. Key areas for contribution:

1. **Error Handling**: Improve error messages and recovery
2. **Performance**: Optimize for large video files
3. **Features**: Add batch processing, more format options
4. **Testing**: Add comprehensive unit and integration tests
5. **Accessibility**: Improve VoiceOver and keyboard navigation

## License

[Specify your license here]

## Support

For issues and feature requests, please create an issue in the project repository.

---

**Disclaimer**: This software is provided as-is for educational and personal use. Users are solely responsible for ensuring their use complies with applicable laws and service terms.