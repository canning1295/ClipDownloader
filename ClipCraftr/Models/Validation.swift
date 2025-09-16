import Foundation

struct Validation {
    
    // MARK: - Time Parsing
    
    /// Parse time string into seconds. Accepts "SS", "MM:SS", or "HH:MM:SS"
    static func parseTime(_ timeString: String) -> Double? {
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let parts = trimmed.split(separator: ":").map(String.init).reversed()
        var seconds = 0.0
        
        for (index, part) in parts.enumerated() {
            guard let value = Double(part), value >= 0 else { return nil }
            
            // Check for valid ranges
            if index == 1 && value >= 60 { return nil } // minutes should be < 60
            if index == 2 && value >= 60 { return nil } // seconds should be < 60
            
            seconds += value * pow(60, Double(index))
        }
        
        return seconds
    }
    
    /// Format seconds back to HH:MM:SS or MM:SS format
    static func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    // MARK: - URL Validation
    
    /// Validate if the URL is a valid YouTube URL
    static func isValidYouTubeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        guard let host = url.host?.lowercased() else { return false }
        
        // Check for various YouTube domains
        let validHosts = [
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "youtu.be",
            "www.youtu.be"
        ]
        
        return validHosts.contains(host)
    }
    
    /// Extract video ID from YouTube URL
    static func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Handle youtu.be format
        if url.host?.lowercased().contains("youtu.be") == true {
            return String(url.lastPathComponent.prefix(11)) // YouTube video IDs are 11 characters
        }
        
        // Handle youtube.com format
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                if item.name == "v", let value = item.value {
                    return String(value.prefix(11))
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Clip Validation
    
    /// Validate a complete clip request
    static func validateClipRequest(_ request: ClipRequest) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // URL validation
        if request.url.isEmpty {
            errors.append(.emptyURL)
        } else if !isValidYouTubeURL(request.url) {
            errors.append(.invalidURL)
        }
        
        // Time validation
        guard let startSeconds = parseTime(request.startTime) else {
            if !request.startTime.isEmpty {
                errors.append(.invalidStartTime)
            }
            return errors // Can't continue without valid start time
        }
        
        guard let endSeconds = parseTime(request.endTime) else {
            if !request.endTime.isEmpty {
                errors.append(.invalidEndTime)
            }
            return errors // Can't continue without valid end time
        }
        
        // Time logic validation
        if endSeconds <= startSeconds {
            errors.append(.endTimeNotAfterStart)
        }
        
        if endSeconds - startSeconds < 1.0 {
            errors.append(.clipTooShort)
        }
        
        // Output folder validation
        if !FileManager.default.fileExists(atPath: request.outputFolder.path) {
            errors.append(.outputFolderNotExists)
        }
        
        return errors
    }
    
    // MARK: - File Name Sanitization
    
    /// Sanitize filename by removing/replacing invalid characters
    static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?*\"<>|")
        let sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        // Remove leading/trailing dots and spaces
        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError, CaseIterable {
    case emptyURL
    case invalidURL
    case invalidStartTime
    case invalidEndTime
    case endTimeNotAfterStart
    case clipTooShort
    case outputFolderNotExists
    
    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return "Please enter a YouTube URL"
        case .invalidURL:
            return "Please enter a valid YouTube URL"
        case .invalidStartTime:
            return "Invalid start time format. Use SS, MM:SS, or HH:MM:SS"
        case .invalidEndTime:
            return "Invalid end time format. Use SS, MM:SS, or HH:MM:SS"
        case .endTimeNotAfterStart:
            return "End time must be after start time"
        case .clipTooShort:
            return "Clip must be at least 1 second long"
        case .outputFolderNotExists:
            return "Output folder does not exist"
        }
    }
}