import Foundation

class FFmpegService {
    
    // MARK: - Command Building
    
    /// Build ffmpeg command arguments for cutting video
    static func buildCutArguments(
        inputFile: URL,
        outputFile: URL,
        request: ClipRequest,
        startSeconds: Double,
        endSeconds: Double
    ) -> [String] {
        
        var args: [String] = []
        
        // Basic ffmpeg options
        args += ["-y"] // Overwrite output file
        
        // Input seeking and duration
        args += ["-ss", Validation.formatTime(startSeconds)]
        args += ["-to", Validation.formatTime(endSeconds)]
        args += ["-i", inputFile.path]
        
        // Codec and quality settings based on accuracy mode
        switch request.accuracy {
        case .keyframeCopy:
            // Fast copy mode - no re-encoding
            args += ["-c", "copy"]
            
        case .frameAccurate:
            // Re-encode for frame accuracy
            if !request.container.isAudioOnly {
                // Video encoding
                args += ["-c:v", "h264_videotoolbox"] // Use Apple's hardware encoder
                
                if let videoBitrate = request.videoBitrateMbps {
                    args += ["-b:v", "\(videoBitrate)M"]
                    args += ["-maxrate", "\(ceil(videoBitrate * 1.5))M"]
                    args += ["-bufsize", "\(Int(videoBitrate * 2))M"]
                }
            }
            
            // Audio encoding
            args += ["-c:a", "aac_at"] // Use Apple's hardware AAC encoder
            if let audioBitrate = request.audioBitrateKbps {
                args += ["-b:a", "\(audioBitrate)k"]
            }
        }
        
        // Container-specific options
        if request.container == .mp4 || request.container == .m4a {
            args += ["-movflags", "+faststart"] // Optimize for streaming
        }
        
        // Progress reporting
        args += ["-progress", "pipe:1"]
        args += ["-nostats"] // Disable default stats to keep output clean
        
        // Output file
        args.append(outputFile.path)
        
        return args
    }
    
    // MARK: - Execution
    
    /// Cut video using ffmpeg
    static func cutVideo(
        inputFile: URL,
        outputFile: URL,
        request: ClipRequest,
        onProgress: @escaping (Double) -> Void = { _ in },
        onLog: @escaping (String) -> Void = { _ in }
    ) async throws -> FFmpegResult {
        
        guard let ffmpegURL = Toolchain.ffmpegURL else {
            throw FFmpegError.binaryNotFound
        }
        
        guard let startSeconds = Validation.parseTime(request.startTime),
              let endSeconds = Validation.parseTime(request.endTime) else {
            throw FFmpegError.invalidTimeRange
        }
        
        let totalDurationSeconds = endSeconds - startSeconds
        let args = buildCutArguments(
            inputFile: inputFile,
            outputFile: outputFile,
            request: request,
            startSeconds: startSeconds,
            endSeconds: endSeconds
        )
        
        onLog("ffmpeg \(args.joined(separator: " "))")
        
        var lastProgress: Double = 0.0
        
        let exitCode = try await ProcessExecutor.runProcess(
            executable: ffmpegURL,
            arguments: args,
            onStdout: { line in
                // Progress is reported on stdout when using -progress pipe:1
                if let progress = parseFFmpegProgress(from: line, totalDuration: totalDurationSeconds) {
                    lastProgress = progress
                    onProgress(progress)
                }
                onLog("[ffmpeg] \(line)")
            },
            onStderr: { line in
                onLog("[ffmpeg error] \(line)")
            }
        )
        
        if exitCode != 0 {
            throw FFmpegError.cuttingFailed(exitCode, "ffmpeg exited with code \(exitCode)")
        }
        
        // Verify output file exists
        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            throw FFmpegError.outputFileNotCreated(outputFile.path)
        }
        
        return FFmpegResult(
            outputFile: outputFile,
            progress: lastProgress,
            duration: totalDurationSeconds
        )
    }
    
    // MARK: - Probe Functions
    
    /// Get video information using ffprobe
    static func probeVideo(at url: URL) async throws -> VideoInfo {
        guard let ffmpegURL = Toolchain.ffmpegURL else {
            throw FFmpegError.binaryNotFound
        }
        
        // Use ffprobe (bundled with ffmpeg) to get video info
        let ffprobeURL = ffmpegURL.deletingLastPathComponent().appendingPathComponent("ffprobe")
        
        let args = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url.path
        ]
        
        let result = try await ProcessExecutor.runProcessWithOutput(
            executable: ffprobeURL.fileExists ? ffprobeURL : ffmpegURL,
            arguments: ffprobeURL.fileExists ? args : ["-f", "ffmetadata"] + args
        )
        
        if result.exitCode != 0 {
            throw FFmpegError.probeError(result.stderr)
        }
        
        guard let data = result.stdout.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FFmpegError.invalidProbeData
        }
        
        return try VideoInfo.from(probeData: json)
    }
    
    // MARK: - Progress Parsing
    
    /// Parse ffmpeg progress from output
    private static func parseFFmpegProgress(from line: String, totalDuration: Double) -> Double? {
        // ffmpeg progress format: key=value pairs
        let progressKeys = line.components(separatedBy: "=")
        
        if progressKeys.count == 2 {
            let key = progressKeys[0].trimmingCharacters(in: .whitespaces)
            let value = progressKeys[1].trimmingCharacters(in: .whitespaces)
            
            if key == "out_time_ms" {
                if let timeMs = Double(value) {
                    let currentSeconds = timeMs / 1_000_000.0 // Convert microseconds to seconds
                    let progress = min(1.0, currentSeconds / totalDuration)
                    return max(0.0, progress)
                }
            } else if key == "out_time" {
                // Format: HH:MM:SS.mmm
                if let currentSeconds = parseFFmpegTime(value) {
                    let progress = min(1.0, currentSeconds / totalDuration)
                    return max(0.0, progress)
                }
            }
        }
        
        return nil
    }
    
    /// Parse ffmpeg time format (HH:MM:SS.mmm)
    private static func parseFFmpegTime(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
}

// MARK: - Supporting Types

struct FFmpegResult {
    let outputFile: URL
    let progress: Double
    let duration: Double
}

struct VideoInfo {
    let duration: Double
    let width: Int?
    let height: Int?
    let frameRate: Double?
    let bitrate: Int?
    let format: String?
    
    static func from(probeData: [String: Any]) throws -> VideoInfo {
        guard let format = probeData["format"] as? [String: Any] else {
            throw FFmpegError.invalidProbeData
        }
        
        let durationString = format["duration"] as? String ?? "0"
        let duration = Double(durationString) ?? 0
        
        let bitrateString = format["bit_rate"] as? String ?? "0"
        let bitrate = Int(bitrateString)
        
        let formatName = format["format_name"] as? String
        
        // Find video stream
        var width: Int?
        var height: Int?
        var frameRate: Double?
        
        if let streams = probeData["streams"] as? [[String: Any]] {
            for stream in streams {
                if let codecType = stream["codec_type"] as? String, codecType == "video" {
                    width = stream["width"] as? Int
                    height = stream["height"] as? Int
                    
                    if let frameRateString = stream["r_frame_rate"] as? String {
                        let components = frameRateString.components(separatedBy: "/")
                        if components.count == 2,
                           let numerator = Double(components[0]),
                           let denominator = Double(components[1]),
                           denominator != 0 {
                            frameRate = numerator / denominator
                        }
                    }
                    break
                }
            }
        }
        
        return VideoInfo(
            duration: duration,
            width: width,
            height: height,
            frameRate: frameRate,
            bitrate: bitrate,
            format: formatName
        )
    }
}

enum FFmpegError: LocalizedError {
    case binaryNotFound
    case invalidTimeRange
    case cuttingFailed(Int32, String)
    case outputFileNotCreated(String)
    case probeError(String)
    case invalidProbeData
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "ffmpeg binary not found"
        case .invalidTimeRange:
            return "Invalid time range for cutting"
        case .cuttingFailed(let code, let message):
            return "Video cutting failed (exit code \(code)): \(message)"
        case .outputFileNotCreated(let path):
            return "Output file was not created at: \(path)"
        case .probeError(let error):
            return "Failed to probe video: \(error)"
        case .invalidProbeData:
            return "Invalid video probe data"
        }
    }
}

// MARK: - File Extension

private extension URL {
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: self.path)
    }
}