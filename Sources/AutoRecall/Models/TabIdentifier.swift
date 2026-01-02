import Foundation
import SwiftUI

// Common TabIdentifier enum for use throughout the app
enum TabIdentifier: String, CaseIterable {
    case timeline = "timeline"
    case search = "search"
    case clipboard = "clipboard"
    case textInput = "textInput"
    case videos = "videos"
    case aiAssistant = "aiAssistant"
    case settings = "settings"
    case about = "about"
    
    var title: String {
        switch self {
        case .timeline:
            return "Timeline"
        case .search:
            return "Search"
        case .clipboard:
            return "Clipboard"
        case .textInput:
            return "Text Input"
        case .videos:
            return "Videos"
        case .aiAssistant:
            return "AI Assistant"
        case .settings:
            return "Settings"
        case .about:
            return "About"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline:
            return "calendar.day.timeline.left"
        case .search:
            return "magnifyingglass"
        case .clipboard:
            return "list.clipboard"
        case .textInput:
            return "text.cursor"
        case .videos:
            return "film"
        case .aiAssistant:
            return "sparkles.square.filled.on.square"
        case .settings:
            return "gearshape"
        case .about:
            return "info.circle"
        }
    }

    var color: Color {
        switch self {
        case .timeline: return .blue
        case .search: return .orange
        case .clipboard: return .green
        case .textInput: return .indigo
        case .videos: return .red
        case .aiAssistant: return .purple
        case .settings: return .gray
        case .about: return .cyan
        }
    }
} 