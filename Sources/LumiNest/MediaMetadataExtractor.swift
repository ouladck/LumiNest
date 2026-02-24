import AVFoundation
import Foundation
import ImageIO

struct MetadataEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct MediaMetadata {
    let entries: [MetadataEntry]
}

enum MediaMetadataExtractor {
    static func extract(for item: MediaItem) -> MediaMetadata {
        var entries: [MetadataEntry] = []

        entries.append(MetadataEntry(label: "Type", value: item.type == .image ? "Photo" : "Video"))
        entries.append(MetadataEntry(label: "Name", value: item.filename))
        entries.append(MetadataEntry(label: "Size", value: ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file)))

        if let createdAt = item.createdAt {
            entries.append(MetadataEntry(label: "Created", value: createdAt.formatted(date: .abbreviated, time: .shortened)))
        }

        if item.type == .image {
            entries.append(contentsOf: imageMetadata(for: item.url))
        } else {
            entries.append(contentsOf: videoMetadata(for: item.url))
        }

        entries.append(MetadataEntry(label: "Path", value: item.url.path))

        return MediaMetadata(entries: entries)
    }

    private static func imageMetadata(for url: URL) -> [MetadataEntry] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return []
        }

        var entries: [MetadataEntry] = []

        if let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int {
            entries.append(MetadataEntry(label: "Resolution", value: "\(width) × \(height)"))
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            let make = (tiff[kCGImagePropertyTIFFMake] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = (tiff[kCGImagePropertyTIFFModel] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let camera = [make, model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if !camera.isEmpty {
                entries.append(MetadataEntry(label: "Camera", value: camera))
            }
        }

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let originalDate = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            entries.append(MetadataEntry(label: "Captured", value: originalDate))
        }

        return entries
    }

    private static func videoMetadata(for url: URL) -> [MetadataEntry] {
        let asset = AVURLAsset(url: url)
        var entries: [MetadataEntry] = []

        let duration = CMTimeGetSeconds(asset.duration)
        if duration.isFinite && duration > 0 {
            entries.append(MetadataEntry(label: "Duration", value: formatDuration(duration)))
        }

        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            let width = Int(abs(transformed.width))
            let height = Int(abs(transformed.height))
            if width > 0, height > 0 {
                entries.append(MetadataEntry(label: "Resolution", value: "\(width) × \(height)"))
            }
        }

        return entries
    }

    private static func formatDuration(_ duration: Double) -> String {
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
