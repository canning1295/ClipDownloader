import Foundation
import SwiftUI

@MainActor
class ClipViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var request = ClipRequest()
    @Published var validationErrors: [ValidationError] = []
    @Published var templateErrors: [TemplateValidationError] = []
    @Published var filenamePreview: String = ""
    
    // MARK: - Dependencies
    
    let orchestrator = JobOrchestrator()
    private let preferences = PreferencesService()
    
    // MARK: - Computed Properties
    
    var canStartJob: Bool {
        return validationErrors.isEmpty && 
               templateErrors.isEmpty && 
               orchestrator.canStart
    }
    
    // MARK: - Initialization
    
    init() {
        validateInput()
        updateFilenamePreview()
    }
    
    // MARK: - Public Methods
    
    func startJob() async {
        guard canStartJob else { return }
        
        // Save current settings as preferences
        savePreferences()
        
        // Start the job
        await orchestrator.startJob(with: request)
    }
    
    func cancelJob() {
        orchestrator.cancelJob()
    }
    
    func validateInput() {
        validationErrors = Validation.validateClipRequest(request)
        templateErrors = FilenameTemplating.validateTemplate(request.filenameTemplate)
    }
    
    func updateFilenamePreview() {
        filenamePreview = FilenameTemplating.previewFilename(
            template: request.filenameTemplate,
            request: request
        )
    }
    
    // MARK: - Preferences
    
    func loadPreferences() {
        request = preferences.loadClipRequest()
        validateInput()
        updateFilenamePreview()
    }
    
    func savePreferences() {
        preferences.saveClipRequest(request)
    }
}

// MARK: - Preferences Service

class PreferencesService {
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let outputFolder = "outputFolder"
        static let filenameTemplate = "filenameTemplate"
        static let quality = "quality"
        static let container = "container"
        static let accuracy = "accuracy"
        static let useDownloadSections = "useDownloadSections"
        static let videoBitrateMbps = "videoBitrateMbps"
        static let audioBitrateKbps = "audioBitrateKbps"
        static let hasShownLegalReminder = "hasShownLegalReminder"
    }
    
    func saveClipRequest(_ request: ClipRequest) {
        // Save output folder
        if let bookmarkData = try? request.outputFolder.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            userDefaults.set(bookmarkData, forKey: Keys.outputFolder)
        }
        
        // Save other preferences
        userDefaults.set(request.filenameTemplate, forKey: Keys.filenameTemplate)
        userDefaults.set(request.quality.rawValue, forKey: Keys.quality)
        userDefaults.set(request.container.rawValue, forKey: Keys.container)
        userDefaults.set(request.accuracy.rawValue, forKey: Keys.accuracy)
        userDefaults.set(request.useDownloadSections, forKey: Keys.useDownloadSections)
        userDefaults.set(request.videoBitrateMbps, forKey: Keys.videoBitrateMbps)
        userDefaults.set(request.audioBitrateKbps, forKey: Keys.audioBitrateKbps)
    }
    
    func loadClipRequest() -> ClipRequest {
        var request = ClipRequest()
        
        // Load output folder
        if let bookmarkData = userDefaults.data(forKey: Keys.outputFolder) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale {
                request.outputFolder = url
            }
        }
        
        // Load other preferences
        if let template = userDefaults.string(forKey: Keys.filenameTemplate), !template.isEmpty {
            request.filenameTemplate = template
        }
        
        if let qualityString = userDefaults.string(forKey: Keys.quality),
           let quality = VideoQuality(rawValue: qualityString) {
            request.quality = quality
        }
        
        if let containerString = userDefaults.string(forKey: Keys.container),
           let container = Container(rawValue: containerString) {
            request.container = container
        }
        
        if let accuracyString = userDefaults.string(forKey: Keys.accuracy),
           let accuracy = Accuracy(rawValue: accuracyString) {
            request.accuracy = accuracy
        }
        
        request.useDownloadSections = userDefaults.bool(forKey: Keys.useDownloadSections)
        
        if userDefaults.object(forKey: Keys.videoBitrateMbps) != nil {
            request.videoBitrateMbps = userDefaults.double(forKey: Keys.videoBitrateMbps)
        }
        
        if userDefaults.object(forKey: Keys.audioBitrateKbps) != nil {
            request.audioBitrateKbps = userDefaults.integer(forKey: Keys.audioBitrateKbps)
        }
        
        return request
    }
    
    var hasShownLegalReminder: Bool {
        get { userDefaults.bool(forKey: Keys.hasShownLegalReminder) }
        set { userDefaults.set(newValue, forKey: Keys.hasShownLegalReminder) }
    }
}