import Foundation
import AppKit
import Combine
import SQLite

/// Manages text input tracking across the system.
/// This class can capture text input from applications and track them
/// with relevant context (app, window, website) for searchable history.
class TextInputManager: ObservableObject {
    static let shared = TextInputManager()
    
    // Published properties
    @Published var isMonitoring = false
    @Published var recentInputs: [TextInput] = []
    
    // Configuration options
    @UserDefault("trackTextInput", defaultValue: true) private var trackTextInput: Bool
    @UserDefault("minimumTextLength", defaultValue: 3) private var minimumTextLength: Int
    @UserDefault("maxStoredTextInputs", defaultValue: 1000) private var maxStoredInputs: Int
    @UserDefault("ignorePasswordFields", defaultValue: true) private var ignorePasswordFields: Bool
    
    // Text grouping management
    private var currentTextBuffer = ""
    private var lastBufferCommitTime: Date?
    private var bufferTimeout: TimeInterval = 2.0 // seconds between text chunks
    private var bufferCommitTimer: Timer?
    
    // Context tracking
    private var currentApp: NSRunningApplication?
    private var currentWindow: String = ""
    private var currentURL: String?
    
    // Core managers
    private let databaseManager = DatabaseManager.shared
    private let processingQueue = DispatchQueue(label: "com.autorecall.textinput.processing", qos: .userInitiated)
    
    // Event monitoring
    private var eventMonitor: EventMonitor?
    private var activeWindowMonitor: Timer?
    
    private init() {
        // Load recent inputs
        loadRecentInputs()
        
        // Listen for app termination to clean up resources
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupResources),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Initialize event monitoring for text input
        eventMonitor = EventMonitor(mask: [.keyDown]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring && trackTextInput else { return }
        
        NSLog("📝 Starting text input monitoring")
        isMonitoring = true
        
        // Track active window/app
        startActiveWindowTracking()
        
        // Set up event monitoring for keystrokes
        eventMonitor?.start()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        NSLog("📝 Stopping text input monitoring")
        isMonitoring = false
        
        // Stop the monitoring timers
        stopActiveWindowTracking()
        
        // Remove event monitor
        eventMonitor?.stop()
        
        // Commit any pending buffer
        commitTextBuffer()
    }
    
    // MARK: - Private Methods
    
    @objc private func cleanupResources() {
        stopMonitoring()
    }
    
    private func loadRecentInputs() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            let inputs = self.databaseManager.getRecentTextInputs(limit: 50)
            
            DispatchQueue.main.async {
                self.recentInputs = inputs
            }
        }
    }
    
    private func startActiveWindowTracking() {
        // Check the active window and application every second
        activeWindowMonitor = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateActiveWindowInfo()
        }
        
        // Initial update
        updateActiveWindowInfo()
    }
    
    private func stopActiveWindowTracking() {
        activeWindowMonitor?.invalidate()
        activeWindowMonitor = nil
    }
    
    private func updateActiveWindowInfo() {
        // Get the frontmost application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            currentApp = frontmostApp
            
            // Get window title for common browsers to extract URL information
            let appName = frontmostApp.localizedName ?? "Unknown"
            
            // Get active window information using Accessibility API
            if let windowTitle = getActiveWindowTitle() {
                currentWindow = windowTitle
                
                // For browsers, try to extract the URL from the window title
                if isBrowser(appName: appName) {
                    currentURL = extractURLFromWindowTitle(windowTitle, appName: appName)
                } else {
                    currentURL = nil
                }
            }
        }
    }
    
    private func getActiveWindowTitle() -> String? {
        if let app = NSWorkspace.shared.frontmostApplication,
           let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            
            for window in windows {
                if let owner = window[kCGWindowOwnerName as String] as? String,
                   owner == app.localizedName,
                   let name = window[kCGWindowName as String] as? String,
                   !name.isEmpty {
                    return name
                }
            }
        }
        return nil
    }
    
    private func isBrowser(appName: String) -> Bool {
        let browsers = ["Safari", "Google Chrome", "Firefox", "Edge", "Brave", "Opera"]
        return browsers.contains { appName.contains($0) }
    }
    
    private func extractURLFromWindowTitle(_ title: String, appName: String) -> String? {
        // Simplified URL extraction logic based on common browser title patterns
        // In a real implementation, this would be more sophisticated using
        // browser-specific accessibility inspection
        return nil
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard isMonitoring, let characters = event.characters else { return }
        
        // Check for field type (ignore password fields)
        if ignorePasswordFields && isPasswordField() {
            return
        }
        
        // Handle special keys
        switch event.keyCode {
        case 36, 76: // Return/Enter keys
            commitTextBuffer()
            return
        case 9: // Tab key
            commitTextBuffer()
            return
        case 53: // Escape key
            currentTextBuffer = ""
            cancelBufferCommitTimer()
            return
        default:
            break
        }
        
        // Append the characters to the current buffer
        currentTextBuffer += characters
        
        // Reset the commit timer
        scheduleBufferCommit()
    }
    
    private func isPasswordField() -> Bool {
        // In a real implementation, use Accessibility API to detect password fields
        // For this example implementation, we'll just return false
        return false
    }
    
    private func scheduleBufferCommit() {
        // Cancel any existing timer
        cancelBufferCommitTimer()
        
        // Schedule a new timer
        bufferCommitTimer = Timer.scheduledTimer(timeInterval: bufferTimeout, 
                                                target: self, 
                                                selector: #selector(timerCommitBuffer), 
                                                userInfo: nil, 
                                                repeats: false)
    }
    
    private func cancelBufferCommitTimer() {
        bufferCommitTimer?.invalidate()
        bufferCommitTimer = nil
    }
    
    @objc private func timerCommitBuffer() {
        commitTextBuffer()
    }
    
    private func commitTextBuffer() {
        guard !currentTextBuffer.isEmpty else { return }
        
        // Ignore text that's too short
        if currentTextBuffer.count < minimumTextLength {
            currentTextBuffer = ""
            return
        }
        
        // Process the text on a background queue
        let textToSave = currentTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTextBuffer = ""
        
        let appName = currentApp?.localizedName ?? "Unknown"
        let windowTitle = currentWindow
        let url = currentURL
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Save to database
            self.databaseManager.saveTextInput(
                text: textToSave,
                appName: appName,
                windowTitle: windowTitle,
                timestamp: Date(),
                url: url
            )
            
            // Update the recent inputs list
            self.loadRecentInputs()
        }
    }
}

// MARK: - Extension for Demo / Testing Purposes

// Comment out the test extension
// extension TextInputManager {
//     /// Simulate text input for testing purposes
//     func simulateTextInput(text: String, appName: String, windowTitle: String, url: String?) {
//         processingQueue.async { [weak self] in
//             guard let self = self else { return }
//             
//             self.databaseManager.saveTextInput(
//                 text: text,
//                 appName: appName,
//                 windowTitle: windowTitle,
//                 timestamp: Date(),
//                 url: url
//             )
//             
//             // Update the recent inputs list
//             self.loadRecentInputs()
//         }
//     }
// }

// Helper class to monitor keyboard events
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
} 