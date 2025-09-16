import Foundation

struct ClipRequest: Codable, Equatable {
    var url: String = ""
    var startTime: String = "" // raw user input
    var endTime: String = ""   // raw user input
    var quality: VideoQuality = .auto1080
    var container: Container = .mp4
    var accuracy: Accuracy = .frameAccurate
    var useDownloadSections: Bool = false
    var videoBitrateMbps: Double? = 5.0 // re-encode only
    var audioBitrateKbps: Int? = 160    // re-encode only
    var outputFolder: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads/ClipCraftr")
    var filenameTemplate: String = "{title}_{start}-{end}.{container}"
    
    init() {
        // Create default output folder if it doesn't exist
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    }
}