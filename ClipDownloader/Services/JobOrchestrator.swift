import Foundation
import Combine

/// Main orchestrator that coordinates yt-dlp download and ffmpeg cutting stages
@MainActor
class JobOrchestrator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var stage: JobStage = .idle
    @Published var downloadProgress: Double = 0.0
    @Published var cuttingProgress: Double = 0.0
    @Published var logMessages: [LogMessage] = []
    @Published var currentError: Error?
    @Published var resultFile: URL?
    
    // MARK: - Private Properties
    
    private var currentJob: CancellableProcess?
    private var tempDirectory: URL?
    private var downloadedFile: URL?
    private var videoMetadata: VideoMetadata?
    
    // MARK: - Computed Properties
    
    var overallProgress: Double {
        switch stage {
        case .idle, .failed, .canceled:
            return 0.0
        case .downloading:
            return downloadProgress * 0.6 // Download takes ~60% of total time
        case .cutting:
            return 0.6 + (cuttingProgress * 0.4) // Cutting takes ~40% of total time
        case .finished:
            return 1.0
        }
    }
    
    var isRunning: Bool {
        return stage == .downloading || stage == .cutting
    }
    
    var canStart: Bool {
        return stage == .idle || stage == .finished || stage == .failed || stage == .canceled
    }
    
    // MARK: - Main Execution
    
    func startJob(with request: ClipRequest) async {
        guard canStart else {
            addLog("Job already running", type: .error)
            return
        }
        
        // Reset state
        await resetState()
        
        do {
            // Validate the request first
            let validationErrors = Validation.validateClipRequest(request)
            if !validationErrors.isEmpty {
                let errorMessage = validationErrors.map(\.localizedDescription).joined(separator: ", ")
                throw JobError.validationFailed(errorMessage)
            }
            
            // Validate binaries
            try Toolchain.validateBinaries()
            
            // Create temporary directory
            tempDirectory = createTempDirectory()
            
            addLog("Starting clip creation job", type: .info)
            addLog("URL: \(request.url)", type: .info)
            addLog("Time range: \(request.startTime) - \(request.endTime)", type: .info)
            
            // Stage 1: Download with yt-dlp
            await downloadVideo(request: request)
            
            // Stage 2: Cut with ffmpeg
            await cutVideo(request: request)
            
            // Stage 3: Finalize
            await finalizeJob(request: request)
            
        } catch {
            await handleError(error)
        }
    }
    
    func cancelJob() {
        guard isRunning else { return }
        
        addLog("Cancelling job...", type: .warning)
        stage = .canceled
        
        currentJob?.cancel()
        currentJob = nil
        
        // Clean up temp directory
        cleanupTempDirectory()
    }
    
    // MARK: - Stage 1: Download
    
    private func downloadVideo(request: ClipRequest) async throws {
        stage = .downloading
        downloadProgress = 0.0
        
        addLog("Starting download with yt-dlp...", type: .info)
        
        guard let tempDir = tempDirectory else {
            throw JobError.tempDirectoryFailed
        }
        
        // Create temp file path
        let tempFile = tempDir.appendingPathComponent("input.%(ext)s")
        
        // Extract metadata first for better filename generation
        do {
            addLog("Extracting video metadata...", type: .info)
            videoMetadata = try await YtDlpService.extractMetadata(from: request.url)
            if let metadata = videoMetadata {
                addLog("Video: \(metadata.title) by \(metadata.uploader ?? "Unknown")", type: .info)
                addLog("Duration: \(metadata.formattedDuration)", type: .info)
            }
        } catch {
            addLog("Warning: Could not extract metadata: \(error.localizedDescription)", type: .warning)
            // Continue without metadata
        }
        
        // Start download
        let cancellableProcess = CancellableProcess()
        currentJob = cancellableProcess
        
        let result = try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try await YtDlpService.download(
                        request: request,
                        outputPath: tempFile,
                        onProgress: { [weak self] progress in
                            Task { @MainActor in
                                self?.downloadProgress = progress
                            }
                        },
                        onLog: { [weak self] message in
                            Task { @MainActor in
                                self?.addLog(message, type: .debug)
                            }
                        }
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        downloadedFile = result.downloadedFile
        addLog("Download completed: \(result.downloadedFile.lastPathComponent)", type: .success)
    }
    
    // MARK: - Stage 2: Cut
    
    private func cutVideo(request: ClipRequest) async throws {
        stage = .cutting
        cuttingProgress = 0.0
        
        guard let inputFile = downloadedFile else {
            throw JobError.noDownloadedFile
        }
        
        addLog("Starting video cutting with ffmpeg...", type: .info)
        
        // Generate final output path
        let outputPath = FilenameTemplating.generateFilePath(
            template: request.filenameTemplate,
            request: request,
            metadata: videoMetadata,
            outputFolder: request.outputFolder
        )
        
        addLog("Output file: \(outputPath.lastPathComponent)", type: .info)
        
        // Start cutting
        let cancellableProcess = CancellableProcess()
        currentJob = cancellableProcess
        
        let result = try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try await FFmpegService.cutVideo(
                        inputFile: inputFile,
                        outputFile: outputPath,
                        request: request,
                        onProgress: { [weak self] progress in
                            Task { @MainActor in
                                self?.cuttingProgress = progress
                            }
                        },
                        onLog: { [weak self] message in
                            Task { @MainActor in
                                self?.addLog(message, type: .debug)
                            }
                        }
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        resultFile = result.outputFile
        addLog("Video cutting completed", type: .success)
    }
    
    // MARK: - Stage 3: Finalize
    
    private func finalizeJob(request: ClipRequest) async {
        guard let outputFile = resultFile else {
            await handleError(JobError.noOutputFile)
            return
        }
        
        // Verify output file
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: outputFile.path) else {
            await handleError(JobError.outputFileNotFound(outputFile.path))
            return
        }
        
        // Get file size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: outputFile.path)
            if let fileSize = attributes[.size] as? Int64 {
                let sizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                addLog("Output file size: \(sizeString)", type: .info)
            }
        } catch {
            addLog("Warning: Could not get file size: \(error.localizedDescription)", type: .warning)
        }
        
        // Clean up temp directory
        cleanupTempDirectory()
        
        stage = .finished
        addLog("Job completed successfully!", type: .success)
        addLog("Saved to: \(outputFile.path)", type: .info)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) async {
        currentError = error
        stage = .failed
        
        addLog("Job failed: \(error.localizedDescription)", type: .error)
        
        // Clean up
        cleanupTempDirectory()
        currentJob = nil
    }
    
    // MARK: - Utilities
    
    private func resetState() async {
        stage = .idle
        downloadProgress = 0.0
        cuttingProgress = 0.0
        currentError = nil
        resultFile = nil
        downloadedFile = nil
        videoMetadata = nil
        
        // Clear old log messages (keep last 50)
        if logMessages.count > 50 {
            logMessages = Array(logMessages.suffix(50))
        }
    }
    
    private func addLog(_ message: String, type: LogType = .info) {
        let logMessage = LogMessage(
            message: message,
            type: type,
            timestamp: Date()
        )
        logMessages.append(logMessage)
        
        // Print to console for debugging
        print("[\(type.rawValue)] \(message)")
    }
    
    private func createTempDirectory() -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let jobTempDir = tempDir.appendingPathComponent("ClipDownloader_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: jobTempDir, withIntermediateDirectories: true)
            addLog("Created temp directory: \(jobTempDir.path)", type: .debug)
            return jobTempDir
        } catch {
            addLog("Failed to create temp directory: \(error.localizedDescription)", type: .error)
            return tempDir // Fallback to system temp
        }
    }
    
    private func cleanupTempDirectory() {
        guard let tempDir = tempDirectory else { return }
        
        do {
            try FileManager.default.removeItem(at: tempDir)
            addLog("Cleaned up temp directory", type: .debug)
        } catch {
            addLog("Warning: Could not clean up temp directory: \(error.localizedDescription)", type: .warning)
        }
        
        tempDirectory = nil
    }
    
    // MARK: - Reveal in Finder
    
    func revealInFinder() {
        guard let file = resultFile else { return }
        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Supporting Types

struct LogMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: LogType
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

enum LogType: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

enum JobError: LocalizedError {
    case validationFailed(String)
    case tempDirectoryFailed
    case noDownloadedFile
    case noOutputFile
    case outputFileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .tempDirectoryFailed:
            return "Failed to create temporary directory"
        case .noDownloadedFile:
            return "No downloaded file available for cutting"
        case .noOutputFile:
            return "No output file was created"
        case .outputFileNotFound(let path):
            return "Output file not found: \(path)"
        }
    }
}