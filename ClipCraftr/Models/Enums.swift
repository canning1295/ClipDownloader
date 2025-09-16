import Foundation

enum VideoQuality: String, CaseIterable, Codable {
    case auto1080 = "auto"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
    
    var displayName: String {
        switch self {
        case .auto1080: return "Auto (best ≤1080p)"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        }
    }
    
    var formatString: String {
        switch self {
        case .auto1080: return "bv*[height<=1080]+ba/b[height<=1080]/b"
        case .p1080: return "bv*[height=1080]+ba/b[height=1080]/b"
        case .p720: return "bv*[height=720]+ba/b[height=720]/b"
        case .p480: return "bv*[height=480]+ba/b[height=480]/b"
        }
    }
}

enum Container: String, CaseIterable, Codable {
    case mp4 = "mp4"
    case webm = "webm"
    case m4a = "m4a"
    case opus = "opus"
    
    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .webm: return "WebM"
        case .m4a: return "Audio-only (M4A)"
        case .opus: return "Audio-only (Opus)"
        }
    }
    
    var isAudioOnly: Bool {
        return self == .m4a || self == .opus
    }
}

enum Accuracy: String, CaseIterable, Codable {
    case frameAccurate = "frame"
    case keyframeCopy = "keyframe"
    
    var displayName: String {
        switch self {
        case .frameAccurate: return "Frame-accurate (re-encode)"
        case .keyframeCopy: return "Keyframe-only (no re-encode)"
        }
    }
    
    var description: String {
        switch self {
        case .frameAccurate: return "Slower, exact timing"
        case .keyframeCopy: return "Very fast, may trim to nearest keyframe"
        }
    }
}

enum JobStage: String, CaseIterable {
    case idle = "idle"
    case downloading = "downloading"
    case cutting = "cutting"
    case finished = "finished"
    case failed = "failed"
    case canceled = "canceled"
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .downloading: return "Fetching & downloading source"
        case .cutting: return "Cutting & encoding"
        case .finished: return "Completed"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        }
    }
}