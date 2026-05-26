import Foundation

enum DownloadKind: String, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Audio"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        }
    }

    var detail: String {
        switch self {
        case .video: "H.264 MP4"
        case .audio: "MP3 320 kbps"
        }
    }
}

enum DownloadStatus: Equatable {
    case queued
    case running
    case finished
    case failed(String)

    var label: String {
        switch self {
        case .queued: "Queued"
        case .running: "Downloading"
        case .finished: "Done"
        case .failed: "Failed"
        }
    }
}

struct DownloadItem: Identifiable, Equatable {
    let id = UUID()
    var url: String
    var kind: DownloadKind
    var status: DownloadStatus = .queued
    var log: String = ""
    var progressPercent: Double? = nil
    var progressText: String = ""
}
