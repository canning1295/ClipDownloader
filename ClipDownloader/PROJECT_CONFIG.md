# ClipDownloader Xcode Project Configuration

This file contains the key Xcode project settings needed for the ClipDownloader app.

## Project Settings

### Basic Information
- Product Name: ClipDownloader
- Bundle Identifier: com.yourname.clipdownloader
- Deployment Target: macOS 15.0+
- Supported Architectures: Apple Silicon (arm64)
- Swift Version: 5.9+

### Build Settings

#### Code Signing
- Signing Certificate: Developer ID Application
- Provisioning Profile: None (for Developer ID)
- Code Signing Style: Manual
- Hardened Runtime: YES
- Enable App Sandbox: NO (required for running external processes)

#### Capabilities and Entitlements
Create an entitlements file (`ClipDownloader.entitlements`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### Build Phases

#### 1. Copy Bundle Resources
- Include: `ClipDownloader/Resources/bin/`

#### 2. Run Script Phase - Sign Embedded Binaries
```bash
# Sign embedded binaries for distribution
if [ "${CONFIGURATION}" = "Release" ]; then
    IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
    
    # Sign yt-dlp
    if [ -f "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/bin/yt-dlp" ]; then
        codesign --force --options runtime --sign "$IDENTITY" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/bin/yt-dlp"
    fi
    
    # Sign ffmpeg
    if [ -f "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/bin/ffmpeg" ]; then
        codesign --force --options runtime --sign "$IDENTITY" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/bin/ffmpeg"
    fi
fi
```

## Info.plist Additions

```xml
<key>NSAppleEventsUsageDescription</key>
<string>ClipDownloader needs to access Apple Events to reveal files in Finder.</string>

<key>NSNetworkVolumesUsageDescription</key>
<string>ClipDownloader needs network access to download videos from YouTube.</string>

<key>NSDownloadsFolderUsageDescription</key>
<string>ClipDownloader can save video clips to your Downloads folder.</string>

<key>LSMinimumSystemVersion</key>
<string>15.0</string>

<key>NSHumanReadableCopyright</key>
<string>Copyright © 2025 Your Name. All rights reserved.</string>

<key>NSPrincipalClass</key>
<string>NSApplication</string>

<key>LSApplicationCategoryType</key>
<string>public.app-category.video</string>
```

## Archive and Notarization

### 1. Archive for Distribution
```bash
xcodebuild -project ClipDownloader.xcodeproj -scheme ClipDownloader -configuration Release -archivePath ClipDownloader.xcarchive archive
```

### 2. Export App
```bash
xcodebuild -exportArchive -archivePath ClipDownloader.xcarchive -exportPath ./export -exportOptionsPlist ExportOptions.plist
```

### 3. Create ExportOptions.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

### 4. Notarize
```bash
xcrun notarytool submit ClipDownloader.app --keychain-profile "notarytool-password" --wait
xcrun stapler staple ClipDownloader.app
```

## Folder Structure
```
ClipDownloader.xcodeproj/
ClipDownloader/
├── ClipDownloaderApp.swift
├── Models/
│   ├── ClipRequest.swift
│   ├── Enums.swift
│   └── Validation.swift
├── Services/
│   ├── Toolchain.swift
│   ├── ProcessExecutor.swift
│   ├── YtDlpService.swift
│   ├── FFmpegService.swift
│   ├── FilenameTemplating.swift
│   └── JobOrchestrator.swift
├── Views/
│   ├── ContentView.swift
│   ├── OptionsView.swift
│   └── OutputView.swift
├── ViewModels/
│   └── ClipViewModel.swift
├── Resources/
│   └── bin/
│       ├── yt-dlp
│       └── ffmpeg
├── ClipDownloader.entitlements
└── Info.plist
```
