import Foundation

class YtDlpService {
    
    // MARK: - Command Building
    
    /// Build yt-dlp command arguments for a clip request
    static func buildArguments(for request: ClipRequest, outputPath: URL) -> [String] {
        var args: [String] = []
        
        // Basic options
        args += ["--no-playlist", "--newline"]
        
        // Format selection based on quality
        args += ["-f", request.quality.formatString]
        
        // Output template
        args += ["-o", outputPath.path]
        
        // Container/format options
        switch request.container {
        case .mp4:
            args += ["--merge-output-format", "mp4"]
        case .webm:
            args += ["--merge-output-format", "webm"]
        case .m4a:
            args += ["-x", "--audio-format", "m4a"]
        case .opus:
            args += ["-x", "--audio-format", "opus"]
        }
        
        // Download sections (experimental feature)
        if request.useDownloadSections,
           let startSeconds = Validation.parseTime(request.startTime),
           let endSeconds = Validation.parseTime(request.endTime) {
            let startFormatted = Validation.formatTime(startSeconds)
            let endFormatted = Validation.formatTime(endSeconds)
            args += ["--download-sections", "*\(startFormatted)-\(endFormatted)"]
        }
        
        // Additional options for better reliability
        args += [
            "--no-check-certificates", // For some networks
            "--socket-timeout", "30",
            "--retries", "3"
        ]
        
        // URL (last argument)
        args.append(request.url)
        
        return args
    }
    
    // MARK: - Execution
    
    /// Download video using yt-dlp
    static func download(
        request: ClipRequest,
        outputPath: URL,
        onProgress: @escaping (Double) -> Void = { _ in },
        onLog: @escaping (String) -> Void = { _ in }
    ) async throws -> YtDlpResult {
        
        guard let ytdlpURL = Toolchain.ytdlpURL else {
            throw YtDlpError.binaryNotFound
        }
        
        let args = buildArguments(for: request, outputPath: outputPath)
        
        onLog("yt-dlp \(args.joined(separator: " "))")
        
        var downloadedFile: URL?
        var metadata: [String: Any] = [:]
        var lastProgress: Double = 0.0
        
        let exitCode = try await ProcessExecutor.runProcess(
            executable: ytdlpURL,
            arguments: args,
            onStdout: { line in
                onLog("[yt-dlp] \(line)")
                
                // Parse progress from download lines
                if let progress = parseDownloadProgress(from: line) {
                    lastProgress = progress
                    onProgress(progress)
                }
                
                // Extract metadata
                if let extractedMetadata = parseMetadata(from: line) {
                    metadata.merge(extractedMetadata) { _, new in new }
                }
            },
            onStderr: { line in
                onLog("[yt-dlp error] \(line)")
                
                // Sometimes progress is reported on stderr
                if let progress = parseDownloadProgress(from: line) {
                    lastProgress = progress
                    onProgress(progress)
                }
            }
        )
        
        // Find the downloaded file
        downloadedFile = try findDownloadedFile(at: outputPath)
        
        if exitCode != 0 {
            throw YtDlpError.downloadFailed(exitCode, "yt-dlp exited with code \(exitCode)")
        }
        
        guard let finalFile = downloadedFile else {
            throw YtDlpError.outputFileNotFound(outputPath.path)
        }
        
        return YtDlpResult(
            downloadedFile: finalFile,
            metadata: metadata,
            progress: lastProgress
        )
    }
    
    // MARK: - Metadata Extraction
    
    /// Extract video metadata using yt-dlp
    static func extractMetadata(from url: String) async throws -> VideoMetadata {
        guard let ytdlpURL = Toolchain.ytdlpURL else {
            throw YtDlpError.binaryNotFound
        }
        
        let args = [
            "--dump-json",
            "--no-download",
            url
        ]
        
        let result = try await ProcessExecutor.runProcessWithOutput(
            executable: ytdlpURL,
            arguments: args
        )
        
        if result.exitCode != 0 {
            throw YtDlpError.metadataExtractionFailed(result.stderr)
        }
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw YtDlpError.invalidMetadata("Could not parse metadata")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let metadata = json else {
            throw YtDlpError.invalidMetadata("Invalid JSON format")
        }
        
        return VideoMetadata(
            id: metadata["id"] as? String ?? "",
            title: metadata["title"] as? String ?? "Unknown Title",
            duration: metadata["duration"] as? Double ?? 0,
            uploader: metadata["uploader"] as? String,
            description: metadata["description"] as? String,
            thumbnailURL: metadata["thumbnail"] as? String,
            viewCount: metadata["view_count"] as? Int,
            uploadDate: metadata["upload_date"] as? String
        )
    }
    
    // MARK: - Progress Parsing
    
    /// Parse download progress from yt-dlp output
    private static func parseDownloadProgress(from line: String) -> Double? {
        // Look for patterns like "[download] 45.2% of 123.45MiB at 1.23MiB/s ETA 00:30"
        let downloadPattern = #"\[download\]\s+(\d+(?:\.\d+)?)%"#
        
        if let regex = try? NSRegularExpression(pattern: downloadPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let percentRange = Range(match.range(at: 1), in: line) {
            
            let percentString = String(line[percentRange])
            if let percent = Double(percentString) {
                return percent / 100.0
            }
        }
        
        return nil
    }
    
    /// Parse metadata from yt-dlp output lines
    private static func parseMetadata(from line: String) -> [String: Any]? {
        // This is a simplified version - in practice, most metadata comes from --dump-json
        var metadata: [String: Any] = [:]
        
        // Extract title from destination filename lines
        if line.contains("[download] Destination:") {
            // Extract filename and try to parse title from it
            let components = line.components(separatedBy: "] ")
            if components.count > 1 {
                let filename = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                metadata["filename"] = filename
            }
        }
        
        return metadata.isEmpty ? nil : metadata
    }
    
    /// Find the downloaded file at the specified path
    private static func findDownloadedFile(at outputPath: URL) throws -> URL {
        let directory = outputPath.deletingLastPathComponent()
        let baseFilename = outputPath.deletingPathExtension().lastPathComponent
        
        // yt-dlp might change the extension, so we need to search for files with the base name
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        
        // Look for exact match first
        if files.contains(outputPath) {
            return outputPath
        }
        
        // Look for files with the same base name but different extension
        for file in files {
            if file.deletingPathExtension().lastPathComponent == baseFilename {
                return file
            }
        }
        
        throw YtDlpError.outputFileNotFound(outputPath.path)
    }
}

// MARK: - Supporting Types

struct YtDlpResult {
    let downloadedFile: URL
    let metadata: [String: Any]
    let progress: Double
}

struct VideoMetadata {
    let id: String
    let title: String
    let duration: Double // in seconds
    let uploader: String?
    let description: String?
    let thumbnailURL: String?
    let viewCount: Int?
    let uploadDate: String?
    
    var formattedDuration: String {
        return Validation.formatTime(duration)
    }
}

enum YtDlpError: LocalizedError {
    case binaryNotFound
    case downloadFailed(Int32, String)
    case outputFileNotFound(String)
    case metadataExtractionFailed(String)
    case invalidMetadata(String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "yt-dlp binary not found"
        case .downloadFailed(let code, let message):
            return "Download failed (exit code \(code)): \(message)"
        case .outputFileNotFound(let path):
            return "Downloaded file not found at: \(path)"
        case .metadataExtractionFailed(let error):
            return "Failed to extract metadata: \(error)"
        case .invalidMetadata(let error):
            return "Invalid metadata: \(error)"
        }
    }
}