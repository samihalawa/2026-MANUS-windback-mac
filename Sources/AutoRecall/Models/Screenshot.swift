//
//  Screenshot.swift
//  AutoRecall
//
//  Type alias for backwards compatibility
//

import Foundation

/// Screenshot is an alias for ScreenshotRecord
typealias Screenshot = ScreenshotRecord

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

// Message struct is defined in AutoRecallApp.swift
