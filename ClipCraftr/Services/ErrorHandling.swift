import Foundation

/// Comprehensive error handling system for ClipCraftr
enum AppError: LocalizedError {
    
    // MARK: - Setup and Configuration Errors
    case missingBinaries([String])
    case binariesNotExecutable([String])
    case invalidConfiguration(String)
    case unsupportedSystem
    
    // MARK: - Network and Download Errors
    case networkUnavailable
    case downloadTimeout
    case youtubeUnavailable
    case videoNotFound
    case videoUnavailable(String)
    case ageRestricted
    case geoBlocked
    case privateVideo
    
    // MARK: - File System Errors
    case outputFolderPermissionDenied(String)
    case diskSpaceInsufficient
    case fileSystemError(String)
    case tempDirectoryFailed
    
    // MARK: - Processing Errors
    case videoCorrupted
    case audioStreamMissing
    case unsupportedFormat(String)
    case encodingFailed(String)
    case cuttingFailed(String)
    
    // MARK: - User Input Errors
    case invalidURL
    case invalidTimeRange
    case clipTooShort
    case clipTooLong
    case timeOutOfBounds(Double)
    
    // MARK: - System Resource Errors
    case memoryExhausted
    case cpuOverload
    case processTerminated
    
    var errorDescription: String? {
        switch self {
        // Setup and Configuration
        case .missingBinaries(let binaries):
            return "Missing required binaries: \(binaries.joined(separator: ", ")). Please reinstall the application."
            
        case .binariesNotExecutable(let binaries):
            return "Cannot execute binaries: \(binaries.joined(separator: ", ")). Check file permissions."
            
        case .invalidConfiguration(let details):
            return "Invalid application configuration: \(details)"
            
        case .unsupportedSystem:
            return "This application requires macOS 13.0 or later."
            
        // Network and Download
        case .networkUnavailable:
            return "No internet connection available. Please check your network settings."
            
        case .downloadTimeout:
            return "Download timed out. Please check your internet connection and try again."
            
        case .youtubeUnavailable:
            return "YouTube is currently unavailable. Please try again later."
            
        case .videoNotFound:
            return "Video not found. The URL may be incorrect or the video may have been removed."
            
        case .videoUnavailable(let reason):
            return "Video unavailable: \(reason)"
            
        case .ageRestricted:
            return "This video is age-restricted and cannot be downloaded."
            
        case .geoBlocked:
            return "This video is not available in your region."
            
        case .privateVideo:
            return "This video is private and cannot be accessed."
            
        // File System
        case .outputFolderPermissionDenied(let path):
            return "Permission denied to write to output folder: \(path). Please choose a different folder or check permissions."
            
        case .diskSpaceInsufficient:
            return "Insufficient disk space. Please free up space and try again."
            
        case .fileSystemError(let details):
            return "File system error: \(details)"
            
        case .tempDirectoryFailed:
            return "Cannot create temporary directory. Check available disk space and permissions."
            
        // Processing
        case .videoCorrupted:
            return "The downloaded video file appears to be corrupted. Please try downloading again."
            
        case .audioStreamMissing:
            return "No audio stream found in the video. Try selecting a different quality or format."
            
        case .unsupportedFormat(let format):
            return "Unsupported video format: \(format). Try selecting a different quality setting."
            
        case .encodingFailed(let details):
            return "Video encoding failed: \(details)"
            
        case .cuttingFailed(let details):
            return "Video cutting failed: \(details)"
            
        // User Input
        case .invalidURL:
            return "Please enter a valid YouTube URL (e.g., https://youtube.com/watch?v=...)"
            
        case .invalidTimeRange:
            return "Invalid time range. End time must be after start time."
            
        case .clipTooShort:
            return "Clip must be at least 1 second long."
            
        case .clipTooLong:
            return "Clip is too long. Maximum supported length is 2 hours."
            
        case .timeOutOfBounds(let duration):
            return "Time range exceeds video duration (\(Validation.formatTime(duration)))"
            
        // System Resources
        case .memoryExhausted:
            return "Insufficient memory to process this video. Try closing other applications or selecting a lower quality."
            
        case .cpuOverload:
            return "System is overloaded. Please wait for other tasks to complete and try again."
            
        case .processTerminated:
            return "Processing was terminated unexpectedly. Please try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingBinaries, .binariesNotExecutable:
            return "Reinstall the application or contact support."
            
        case .networkUnavailable, .downloadTimeout:
            return "Check your internet connection and try again."
            
        case .youtubeUnavailable:
            return "Wait a few minutes and try again. YouTube may be experiencing temporary issues."
            
        case .videoNotFound, .privateVideo:
            return "Verify the URL is correct and the video is publicly accessible."
            
        case .ageRestricted, .geoBlocked:
            return "Try a different video or use a VPN if appropriate."
            
        case .outputFolderPermissionDenied:
            return "Choose a different output folder or grant permission to the current folder."
            
        case .diskSpaceInsufficient:
            return "Free up disk space by deleting unnecessary files."
            
        case .videoCorrupted:
            return "Try downloading again or select a different quality."
            
        case .unsupportedFormat:
            return "Select a different quality or container format."
            
        case .invalidTimeRange, .clipTooShort, .clipTooLong:
            return "Adjust the start and end times to create a valid clip."
            
        case .memoryExhausted:
            return "Close other applications or restart your computer."
            
        case .cpuOverload:
            return "Wait for other tasks to complete before starting a new clip."
            
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .missingBinaries, .binariesNotExecutable, .unsupportedSystem, .invalidConfiguration:
            return false // These require app reinstallation or system upgrade
            
        case .ageRestricted, .geoBlocked, .privateVideo:
            return false // These are video-specific restrictions
            
        default:
            return true // Most other errors can be recovered from
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .missingBinaries, .unsupportedSystem:
            return .critical
            
        case .binariesNotExecutable, .invalidConfiguration, .tempDirectoryFailed:
            return .high
            
        case .networkUnavailable, .diskSpaceInsufficient, .memoryExhausted:
            return .medium
            
        default:
            return .low
        }
    }
}

enum ErrorSeverity {
    case low      // User can easily fix
    case medium   // May require user action
    case high     // Requires technical intervention
    case critical // App cannot function
}

// MARK: - Error Handling Utilities

class ErrorHandler {
    
    /// Convert system errors to AppError
    static func handleSystemError(_ error: Error) -> AppError {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            return handleNetworkError(nsError)
            
        case NSCocoaErrorDomain:
            return handleFileSystemError(nsError)
            
        case NSPOSIXErrorDomain:
            return handlePOSIXError(nsError)
            
        default:
            if let toolchainError = error as? ToolchainError {
                return handleToolchainError(toolchainError)
            } else if let ytdlpError = error as? YtDlpError {
                return handleYtDlpError(ytdlpError)
            } else if let ffmpegError = error as? FFmpegError {
                return handleFFmpegError(ffmpegError)
            } else {
                return .invalidConfiguration(error.localizedDescription)
            }
        }
    }
    
    private static func handleNetworkError(_ error: NSError) -> AppError {
        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .downloadTimeout
        case NSURLErrorBadURL:
            return .invalidURL
        default:
            return .youtubeUnavailable
        }
    }
    
    private static func handleFileSystemError(_ error: NSError) -> AppError {
        switch error.code {
        case NSFileWriteFileExistsError, NSFileWriteNoPermissionError:
            return .outputFolderPermissionDenied(error.localizedDescription)
        case NSFileWriteVolumeReadOnlyError:
            return .fileSystemError("Volume is read-only")
        default:
            return .fileSystemError(error.localizedDescription)
        }
    }
    
    private static func handlePOSIXError(_ error: NSError) -> AppError {
        switch error.code {
        case ENOSPC:
            return .diskSpaceInsufficient
        case EACCES, EPERM:
            return .outputFolderPermissionDenied("Permission denied")
        case ENOMEM:
            return .memoryExhausted
        default:
            return .fileSystemError("System error: \(error.localizedDescription)")
        }
    }
    
    private static func handleToolchainError(_ error: ToolchainError) -> AppError {
        switch error {
        case .missingBinary(let name):
            return .missingBinaries([name])
        case .binaryNotExecutable(let name, _):
            return .binariesNotExecutable([name])
        default:
            return .invalidConfiguration(error.localizedDescription)
        }
    }
    
    private static func handleYtDlpError(_ error: YtDlpError) -> AppError {
        switch error {
        case .downloadFailed(_, let message):
            if message.contains("Private video") {
                return .privateVideo
            } else if message.contains("age") {
                return .ageRestricted
            } else if message.contains("geo") || message.contains("region") {
                return .geoBlocked
            } else if message.contains("not available") {
                return .videoUnavailable(message)
            } else {
                return .videoNotFound
            }
        case .outputFileNotFound:
            return .fileSystemError("Download completed but file not found")
        default:
            return .videoUnavailable(error.localizedDescription)
        }
    }
    
    private static func handleFFmpegError(_ error: FFmpegError) -> AppError {
        switch error {
        case .cuttingFailed(_, let message):
            if message.contains("No space") {
                return .diskSpaceInsufficient
            } else {
                return .cuttingFailed(message)
            }
        case .invalidTimeRange:
            return .invalidTimeRange
        case .outputFileNotCreated:
            return .fileSystemError("Could not create output file")
        default:
            return .encodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Error Reporting

class ErrorReporter {
    
    /// Log error for debugging
    static func logError(_ error: Error, context: String = "") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let errorInfo = [
            "timestamp": timestamp,
            "context": context,
            "error": error.localizedDescription,
            "type": String(describing: type(of: error))
        ]
        
        print("ERROR: \(errorInfo)")
        
        // In a production app, you might send this to a logging service
        // Analytics.logError(errorInfo)
    }
    
    /// Generate user-friendly error message
    static func userMessage(for error: Error) -> (title: String, message: String, suggestion: String?) {
        let appError: AppError
        
        if let existing = error as? AppError {
            appError = existing
        } else {
            appError = ErrorHandler.handleSystemError(error)
        }
        
        let title = appError.severity == .critical ? "Critical Error" : "Error"
        let message = appError.localizedDescription
        let suggestion = appError.recoverySuggestion
        
        return (title, message, suggestion)
    }
}