import Foundation

class FilenameTemplating {
    
    // MARK: - Token Replacement
    
    /// Replace tokens in filename template with actual values
    static func processTemplate(
        _ template: String,
        request: ClipRequest,
        metadata: VideoMetadata?
    ) -> String {
        
        var filename = template
        
        // Basic token replacements
        filename = filename.replacingOccurrences(of: "{container}", with: request.container.rawValue)
        
        // Time tokens
        if let startSeconds = Validation.parseTime(request.startTime) {
            let startFormatted = Validation.formatTime(startSeconds).replacingOccurrences(of: ":", with: "-")
            filename = filename.replacingOccurrences(of: "{start}", with: startFormatted)
        }
        
        if let endSeconds = Validation.parseTime(request.endTime) {
            let endFormatted = Validation.formatTime(endSeconds).replacingOccurrences(of: ":", with: "-")
            filename = filename.replacingOccurrences(of: "{end}", with: endFormatted)
        }
        
        // Resolution token
        let resolution = determineResolution(from: request.quality)
        filename = filename.replacingOccurrences(of: "{res}", with: resolution)
        
        // Video ID token
        if let videoID = Validation.extractVideoID(from: request.url) {
            filename = filename.replacingOccurrences(of: "{id}", with: videoID)
        }
        
        // Metadata-based tokens
        if let metadata = metadata {
            let sanitizedTitle = Validation.sanitizeFileName(metadata.title)
            filename = filename.replacingOccurrences(of: "{title}", with: sanitizedTitle)
            
            if let uploader = metadata.uploader {
                let sanitizedUploader = Validation.sanitizeFileName(uploader)
                filename = filename.replacingOccurrences(of: "{uploader}", with: sanitizedUploader)
            }
            
            if let uploadDate = metadata.uploadDate {
                filename = filename.replacingOccurrences(of: "{date}", with: uploadDate)
            }
            
            let durationFormatted = Validation.formatTime(metadata.duration).replacingOccurrences(of: ":", with: "-")
            filename = filename.replacingOccurrences(of: "{duration}", with: durationFormatted)
        }
        
        // Fallback for missing metadata
        filename = filename.replacingOccurrences(of: "{title}", with: "Unknown_Title")
        filename = filename.replacingOccurrences(of: "{uploader}", with: "Unknown_Uploader")
        filename = filename.replacingOccurrences(of: "{date}", with: getCurrentDateString())
        filename = filename.replacingOccurrences(of: "{duration}", with: "00-00-00")
        
        // Clean up any remaining tokens
        filename = removeUnresolvedTokens(filename)
        
        // Final sanitization
        filename = Validation.sanitizeFileName(filename)
        
        // Ensure we have a valid filename
        if filename.isEmpty || filename == "." {
            filename = "clip_\(UUID().uuidString.prefix(8))"
        }
        
        return filename
    }
    
    /// Generate a complete file path with proper extension
    static func generateFilePath(
        template: String,
        request: ClipRequest,
        metadata: VideoMetadata?,
        outputFolder: URL
    ) -> URL {
        
        let baseFilename = processTemplate(template, request: request, metadata: metadata)
        let extension = determineFileExtension(for: request.container)
        
        var filename = baseFilename
        if !filename.hasSuffix(".\(extension)") {
            filename += ".\(extension)"
        }
        
        let outputPath = outputFolder.appendingPathComponent(filename)
        
        // Handle filename conflicts
        return resolveFileConflict(outputPath)
    }
    
    // MARK: - Preview Generation
    
    /// Generate a preview of the filename without metadata
    static func previewFilename(template: String, request: ClipRequest) -> String {
        let mockMetadata = VideoMetadata(
            id: "ABC123DEF45",
            title: "Sample Video Title",
            duration: 3661, // 1:01:01
            uploader: "Example Channel",
            description: nil,
            thumbnailURL: nil,
            viewCount: 12345,
            uploadDate: "20240101"
        )
        
        return processTemplate(template, request: request, metadata: mockMetadata)
    }
    
    // MARK: - Validation
    
    /// Validate that a template contains reasonable tokens
    static func validateTemplate(_ template: String) -> [TemplateValidationError] {
        var errors: [TemplateValidationError] = []
        
        // Check for empty template
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTemplate)
            return errors
        }
        
        // Check for invalid characters before token replacement
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let templateWithoutTokens = removeAllTokens(template)
        if templateWithoutTokens.rangeOfCharacter(from: invalidChars) != nil {
            errors.append(.invalidCharacters)
        }
        
        // Check for potentially problematic patterns
        if template.contains("..") {
            errors.append(.pathTraversal)
        }
        
        // Suggest including essential tokens
        if !template.contains("{title}") && !template.contains("{id}") {
            errors.append(.missingIdentifier)
        }
        
        return errors
    }
    
    // MARK: - Helper Functions
    
    /// Determine resolution string from quality setting
    private static func determineResolution(from quality: VideoQuality) -> String {
        switch quality {
        case .auto1080: return "auto"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        }
    }
    
    /// Determine file extension from container
    private static func determineFileExtension(for container: Container) -> String {
        return container.rawValue
    }
    
    /// Get current date string in YYYYMMDD format
    private static func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
    
    /// Remove unresolved tokens from filename
    private static func removeUnresolvedTokens(_ filename: String) -> String {
        // Remove any remaining {token} patterns
        let pattern = #"\{[^}]+\}"#
        return filename.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }
    
    /// Remove all tokens for validation
    private static func removeAllTokens(_ template: String) -> String {
        let pattern = #"\{[^}]*\}"#
        return template.replacingOccurrences(
            of: pattern,
            with: "X",
            options: .regularExpression
        )
    }
    
    /// Resolve file naming conflicts by appending numbers
    private static func resolveFileConflict(_ originalURL: URL) -> URL {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: originalURL.path) {
            return originalURL
        }
        
        let directory = originalURL.deletingLastPathComponent()
        let filename = originalURL.deletingPathExtension().lastPathComponent
        let ext = originalURL.pathExtension
        
        var counter = 1
        var newURL: URL
        
        repeat {
            let newFilename = "\(filename) (\(counter))"
            newURL = directory.appendingPathComponent(newFilename).appendingPathExtension(ext)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path) && counter < 1000
        
        return newURL
    }
}

// MARK: - Template Validation

enum TemplateValidationError: LocalizedError {
    case emptyTemplate
    case invalidCharacters
    case pathTraversal
    case missingIdentifier
    
    var errorDescription: String? {
        switch self {
        case .emptyTemplate:
            return "Template cannot be empty"
        case .invalidCharacters:
            return "Template contains invalid characters"
        case .pathTraversal:
            return "Template contains path traversal patterns (..)"
        case .missingIdentifier:
            return "Template should include {title} or {id} for unique filenames"
        }
    }
}

// MARK: - Predefined Templates

extension FilenameTemplating {
    
    /// Common filename templates
    static let predefinedTemplates: [TemplatePreset] = [
        TemplatePreset(
            name: "Default",
            template: "{title}_{start}-{end}.{container}",
            description: "Title with time range"
        ),
        TemplatePreset(
            name: "With Uploader",
            template: "{uploader} - {title}_{start}-{end}.{container}",
            description: "Channel name and title with time range"
        ),
        TemplatePreset(
            name: "Date and Time",
            template: "{date}_{title}_{start}-{end}.{container}",
            description: "Upload date, title and time range"
        ),
        TemplatePreset(
            name: "Video ID",
            template: "{id}_{start}-{end}.{container}",
            description: "YouTube video ID with time range"
        ),
        TemplatePreset(
            name: "Simple",
            template: "{title}.{container}",
            description: "Just the video title"
        ),
        TemplatePreset(
            name: "Descriptive",
            template: "{uploader} - {title} [{res}] ({start}-{end}).{container}",
            description: "Full descriptive format"
        )
    ]
}

struct TemplatePreset {
    let name: String
    let template: String
    let description: String
}