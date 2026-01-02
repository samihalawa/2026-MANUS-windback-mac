import Foundation
import AppKit

enum ClipboardItemType: String, Codable {
    case text
    case image
    case file
    case fileList
    case rtf
    case html
    case url
    case color
    case pdf
    case sound
    case movie
    case unknown
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String?
    let type: ClipboardItemType
    let timestamp: Date
    let data: Data?
    
    var previewText: String {
        if let text = text, !text.isEmpty {
            return text.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "[\(type.rawValue)]"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
} 