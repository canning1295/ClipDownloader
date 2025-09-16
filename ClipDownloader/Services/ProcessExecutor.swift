import Foundation

/// Secure process execution helper with async stdout/stderr reading
actor ProcessExecutor {
    
    // MARK: - Process Execution
    
    /// Execute a process with async stdout/stderr handling
    static func runProcess(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil,
        onStdout: @escaping (String) -> Void = { _ in },
        onStderr: @escaping (String) -> Void = { _ in }
    ) async throws -> Int32 {
        
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        
        // Set up environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env
        
        // Set working directory if provided
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        
        // Set up pipes
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        // Start the process
        try process.run()
        
        // Start async readers for stdout and stderr
        let stdoutTask = Task {
            for try await line in outPipe.fileHandleForReading.bytes.lines {
                onStdout(String(line))
            }
        }
        
        let stderrTask = Task {
            for try await line in errPipe.fileHandleForReading.bytes.lines {
                onStderr(String(line))
            }
        }
        
        // Wait for process completion
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
        
        // Clean up tasks
        stdoutTask.cancel()
        stderrTask.cancel()
        
        return process.terminationStatus
    }
    
    /// Execute a process and collect all output
    static func runProcessWithOutput(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil
    ) async throws -> ProcessResult {
        
        var stdoutLines: [String] = []
        var stderrLines: [String] = []
        
        let exitCode = try await runProcess(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            onStdout: { line in
                stdoutLines.append(line)
            },
            onStderr: { line in
                stderrLines.append(line)
            }
        )
        
        return ProcessResult(
            exitCode: exitCode,
            stdout: stdoutLines.joined(separator: "\n"),
            stderr: stderrLines.joined(separator: "\n")
        )
    }
}

// MARK: - Cancellable Process

/// A process that can be cancelled
class CancellableProcess {
    private var process: Process?
    private var isCancelled = false
    
    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil,
        onStdout: @escaping (String) -> Void = { _ in },
        onStderr: @escaping (String) -> Void = { _ in }
    ) async throws -> Int32 {
        
        guard !isCancelled else {
            throw ProcessError.cancelled
        }
        
        let process = Process()
        self.process = process
        
        process.executableURL = executable
        process.arguments = arguments
        
        // Set up environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env
        
        // Set working directory if provided
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        
        // Set up pipes
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        // Check for cancellation before starting
        guard !isCancelled else {
            throw ProcessError.cancelled
        }
        
        // Start the process
        try process.run()
        
        // Start async readers
        let stdoutTask = Task {
            for try await line in outPipe.fileHandleForReading.bytes.lines {
                guard !Task.isCancelled else { break }
                onStdout(String(line))
            }
        }
        
        let stderrTask = Task {
            for try await line in errPipe.fileHandleForReading.bytes.lines {
                guard !Task.isCancelled else { break }
                onStderr(String(line))
            }
        }
        
        // Wait for process completion or cancellation
        let exitCode = await withCheckedContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            
            // Check for cancellation periodically
            Task {
                while process.isRunning && !isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                
                if isCancelled && process.isRunning {
                    process.terminate()
                    // Give it a moment to terminate gracefully
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if process.isRunning {
                        process.kill()
                    }
                }
            }
        }
        
        // Clean up tasks
        stdoutTask.cancel()
        stderrTask.cancel()
        
        if isCancelled {
            throw ProcessError.cancelled
        }
        
        return exitCode
    }
    
    func cancel() {
        isCancelled = true
        process?.terminate()
        
        // Force kill after a timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let process = self?.process, process.isRunning {
                process.kill()
            }
        }
    }
}

// MARK: - Supporting Types

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    
    var isSuccess: Bool {
        return exitCode == 0
    }
}

enum ProcessError: LocalizedError {
    case cancelled
    case executionFailed(Int32, String)
    case invalidExecutable(URL)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Process was cancelled"
        case .executionFailed(let code, let error):
            return "Process failed with exit code \(code): \(error)"
        case .invalidExecutable(let url):
            return "Invalid executable: \(url.path)"
        }
    }
}