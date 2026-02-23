import Foundation

enum MediaType {
    case image
    case video
}

struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let type: MediaType

    var filename: String {
        url.lastPathComponent
    }
}
