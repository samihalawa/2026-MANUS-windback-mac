//
//  Screenshot.swift
//  AutoRecall
//
//  Core model for screen captures
//

import Foundation

/// Main Screenshot model used throughout the app
struct Screenshot: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let filename: String
    let path: String
    var ocrText: String
    let appName: String
    let windowTitle: String

    // Additional metadata
    var url: String?
    var isClipboardItem: Bool = false
    var isTranscription: Bool = false

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        filename: String,
        path: String,
        ocrText: String = "",
        appName: String = "",
        windowTitle: String = "",
        url: String? = nil,
        isClipboardItem: Bool = false,
        isTranscription: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.filename = filename
        self.path = path
        self.ocrText = ocrText
        self.appName = appName
        self.windowTitle = windowTitle
        self.url = url
        self.isClipboardItem = isClipboardItem
        self.isTranscription = isTranscription
    }

    /// Convert from ScreenshotRecord (for backwards compatibility)
    init(from record: ScreenshotRecord) {
        self.id = UUID(uuidString: record.id) ?? UUID()
        self.timestamp = record.timestamp
        self.filename = record.filename
        self.path = record.path
        self.ocrText = record.ocrText
        self.appName = record.appName
        self.windowTitle = record.windowTitle
        self.url = record.url
        self.isClipboardItem = record.isClipboardItem
        self.isTranscription = record.isTranscription
    }
}

// MARK: - TextInput model
struct TextInput: Identifiable, Codable {
    let id: Int64
    let text: String
    let appName: String
    let windowTitle: String
    let timestamp: Date
    let url: String?

    init(
        id: Int64 = 0,
        text: String,
        appName: String,
        windowTitle: String,
        timestamp: Date = Date(),
        url: String? = nil
    ) {
        self.id = id
        self.text = text
        self.appName = appName
        self.windowTitle = windowTitle
        self.timestamp = timestamp
        self.url = url
    }
}

// MARK: - Message model for AI chat
struct Message: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
