import Foundation

enum Toolchain {
    
    // MARK: - Binary Path Resolution
    
    /// Get the URL for a bundled binary
    static func binURL(_ name: String) -> URL? {
        return Bundle.main.url(forResource: "bin/\(name)", withExtension: nil)
    }
    
    /// Get the URL for yt-dlp binary
    static var ytdlpURL: URL? {
        return binURL("yt-dlp")
    }
    
    /// Get the URL for ffmpeg binary
    static var ffmpegURL: URL? {
        return binURL("ffmpeg")
    }
    
    // MARK: - Binary Validation
    
    /// Check if all required binaries are present and executable
    static func validateBinaries() throws {
        guard let ytdlpURL = ytdlpURL else {
            throw ToolchainError.missingBinary("yt-dlp")
        }
        
        guard let ffmpegURL = ffmpegURL else {
            throw ToolchainError.missingBinary("ffmpeg")
        }
        
        // Check if files exist
        guard FileManager.default.fileExists(atPath: ytdlpURL.path) else {
            throw ToolchainError.binaryNotFound("yt-dlp", ytdlpURL.path)
        }
        
        guard FileManager.default.fileExists(atPath: ffmpegURL.path) else {
            throw ToolchainError.binaryNotFound("ffmpeg", ffmpegURL.path)
        }
        
        // Check if files are executable
        guard FileManager.default.isExecutableFile(atPath: ytdlpURL.path) else {
            throw ToolchainError.binaryNotExecutable("yt-dlp", ytdlpURL.path)
        }
        
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            throw ToolchainError.binaryNotExecutable("ffmpeg", ffmpegURL.path)
        }
    }
    
    /// Attempt to make binaries executable if they're not already
    static func ensureExecutable() throws {
        guard let ytdlpURL = ytdlpURL, let ffmpegURL = ffmpegURL else {
            throw ToolchainError.missingBinary("binary resolution failed")
        }
        
        let fileManager = FileManager.default
        
        // Make yt-dlp executable
        if !fileManager.isExecutableFile(atPath: ytdlpURL.path) {
            var attributes = try fileManager.attributesOfItem(atPath: ytdlpURL.path)
            var permissions = attributes[.posixPermissions] as? NSNumber ?? NSNumber(value: 0o644)
            permissions = NSNumber(value: permissions.uint16Value | 0o111) // Add execute permission
            attributes[.posixPermissions] = permissions
            try fileManager.setAttributes(attributes, ofItemAtPath: ytdlpURL.path)
        }
        
        // Make ffmpeg executable
        if !fileManager.isExecutableFile(atPath: ffmpegURL.path) {
            var attributes = try fileManager.attributesOfItem(atPath: ffmpegURL.path)
            var permissions = attributes[.posixPermissions] as? NSNumber ?? NSNumber(value: 0o644)
            permissions = NSNumber(value: permissions.uint16Value | 0o111) // Add execute permission
            attributes[.posixPermissions] = permissions
            try fileManager.setAttributes(attributes, ofItemAtPath: ffmpegURL.path)
        }
    }
    
    // MARK: - Version Information
    
    /// Get version information for yt-dlp (async)
    static func getYtDlpVersion() async throws -> String {
        guard let ytdlpURL = ytdlpURL else {
            throw ToolchainError.missingBinary("yt-dlp")
        }
        
        let process = Process()
        process.executableURL = ytdlpURL
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw ToolchainError.versionCheckFailed("yt-dlp", output)
        }
    }
    
    /// Get version information for ffmpeg (async)
    static func getFFmpegVersion() async throws -> String {
        guard let ffmpegURL = ffmpegURL else {
            throw ToolchainError.missingBinary("ffmpeg")
        }
        
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = ["-version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            // Extract just the version line from ffmpeg output
            let lines = output.components(separatedBy: .newlines)
            if let versionLine = lines.first(where: { $0.contains("ffmpeg version") }) {
                return versionLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw ToolchainError.versionCheckFailed("ffmpeg", output)
        }
    }
}

// MARK: - Toolchain Errors

enum ToolchainError: LocalizedError {
    case missingBinary(String)
    case binaryNotFound(String, String)
    case binaryNotExecutable(String, String)
    case versionCheckFailed(String, String)
    
    var errorDescription: String? {
        switch self {
        case .missingBinary(let name):
            return "Missing binary: \(name)"
        case .binaryNotFound(let name, let path):
            return "Binary not found: \(name) at \(path)"
        case .binaryNotExecutable(let name, let path):
            return "Binary not executable: \(name) at \(path)"
        case .versionCheckFailed(let name, let output):
            return "Version check failed for \(name): \(output)"
        }
    }
}