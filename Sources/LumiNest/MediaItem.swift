import Foundation

enum MediaType {
    case image
    case video
}

struct MediaItem: Identifiable, Hashable {
    let url: URL
    let type: MediaType
    let createdAt: Date?
    let fileSize: Int64

    var id: URL { url }

    var filename: String {
        url.lastPathComponent
    }
}
