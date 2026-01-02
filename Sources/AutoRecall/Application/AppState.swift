import SwiftUI
import Combine
import Foundation

// Define StorageUsage struct
struct StorageUsage {
    var screenshotSize: Int64 = 0
    var clipboardSize: Int64 = 0
    var videoSize: Int64 = 0
    var audioSize: Int64 = 0
    
    var totalSize: Int64 {
        return screenshotSize + clipboardSize + videoSize + audioSize
    }
    
    func formattedSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Main App State

class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    
    @Published var selectedTab: TabIdentifier = .timeline
    @Published var isRecording = false
    @Published var isCapturing = false
    @Published var isRecordingVideo = false
    @Published var isRecordingAudio = false
    @Published var isMonitoringTextInput = false
    @Published var storageUsage: StorageUsage = StorageUsage()
    @Published var storagePercentage: Double = 0.0 // For progress indicator
    @Published var aiLocalProcessing: Bool = UserDefaults.standard.bool(forKey: "aiLocalProcessing")
    @Published var globalSearch: String = ""
    @Published var isGlobalSearchActive: Bool = false
    @Published var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "isDarkMode")
    @Published var hasRequiredPermissions: Bool = false
    
    // Recording state properties
    @Published var isPaused: Bool = false
    @Published var recordAudio: Bool = UserDefaults.standard.bool(forKey: "recordAudio")
    @Published var recordVideo: Bool = UserDefaults.standard.bool(forKey: "recordVideo")
    @Published var recordingStartTime: Date = Date()
    @Published var recordingTimer: Timer?
    @Published var recordingDuration: TimeInterval = 0
    
    // Storage properties
    @Published var totalStorageSize: Int64 = 0
    @Published var screenshotsStorageSize: Int64 = 0
    @Published var videosStorageSize: Int64 = 0
    @Published var screenshotCount: Int = 0
    @Published var videoCount: Int = 0
    
    // Timer for periodic stats update
    private var statsUpdateTimer: Timer?
    
    // Formatted recording duration (HH:MM:SS)
    var formattedRecordingDuration: String {
        let seconds = Int(recordingDuration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    
    // MARK: - Storage and Performance Properties
    
    // Maximum storage limit (configurable)
    @UserDefault("storageLimit", defaultValue: 50.0) private var storageLimit: Double
    
    var formattedUsedStorage: String {
        // Use placeholder as StorageManager might be stubbed
        // return StorageManager.shared.formatStorageSize(totalStorageSize)
        return ByteCountFormatter.string(fromByteCount: totalStorageSize, countStyle: .file)
    }
    
    var formattedTotalStorage: String {
        return "\(Int(storageLimit)) GB"
    }
    
    // Path to default storage location
    var defaultStoragePath: String {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            NSLog("⚠️ Could not access app support directory, using temp directory")
            return NSTemporaryDirectory() + "AutoRecall"
        }
        return appSupportURL.appendingPathComponent("AutoRecall").path
    }
    
    // MARK: - Initialization
    
    private init() {
        // Schedule timer to update storage stats periodically
        startStatsUpdateTimer()
        
        // Calculate initial storage stats
        calculateStorageStats()
    }
    
    // For SwiftUI previews only - using actual shared instance
    static func preview() -> AppState {
        return AppState.shared
    }
    
    // MARK: - Storage Methods
    
    func calculateStorageStats() {
        // Use placeholder as ScreenshotManager might rely on stubbed StorageManager
        // let screenshotManager = ScreenshotManager.shared
        // let screenshotSize = screenshotManager.getScreenshotFileSize()
        let screenshotSize: Int64 = 0 // Placeholder
        
        // Update the StorageUsage object
        var usage = StorageUsage()
        usage.screenshotSize = Int64(screenshotSize)
        
        // Store the updated object
        storageUsage = usage
        
        // Calculate storage percentage for the progress bar
        let totalStorageSize = Double(usage.totalSize)
        let storageLimitBytes = 1024 * 1024 * 1024 * Double(storageLimit) // Use storageLimit
        
        storagePercentage = storageLimitBytes > 0 ? min(1.0, totalStorageSize / storageLimitBytes) : 0.0
    }
    
    func startStatsUpdateTimer() {
        // Update stats every 5 minutes
        statsUpdateTimer?.invalidate()
        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.calculateStorageStats()
        }
    }
    
    func stopStatsUpdateTimer() {
        statsUpdateTimer?.invalidate()
        statsUpdateTimer = nil
    }
    
    deinit {
        stopStatsUpdateTimer()
    }
    
    // MARK: - Theme Methods
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
    
    // MARK: - Recording Methods
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        
        // Start the recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.recordingDuration += 1.0
        }
        
        // Start screenshot capture
        ScreenshotManager.shared.startCapturing()
        
        // Start clipboard monitoring
        ClipboardManager.shared.startMonitoring()
        
        // Start text input monitoring
        TextInputManager.shared.startMonitoring()
        isMonitoringTextInput = true
        
        // Start video recording if enabled - use public methods
        if recordVideo {
            Task {
                await ScreenshotManager.shared.startVideoRecording()
            }
        }
        
        // Start audio recording if enabled - use public methods
        if recordAudio {
            ScreenshotManager.shared.startAudioRecording()
        }
        
        // Log the recording start
        NSLog("🔴 Recording started")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        isPaused = false
        
        // Stop the recording timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
        
        // Stop screenshot capture
        ScreenshotManager.shared.stopCapturing()
        
        // Stop clipboard monitoring
        ClipboardManager.shared.stopMonitoring()
        
        // Stop text input monitoring
        TextInputManager.shared.stopMonitoring()
        isMonitoringTextInput = false
        
        // Stop video recording if it was active - use public methods
        if recordVideo {
            Task {
                await ScreenshotManager.shared.stopVideoRecording()
            }
        }
        
        // Stop audio recording if it was active - use public methods
        if recordAudio {
            ScreenshotManager.shared.stopAudioRecording()
        }
        
        // Recalculate storage stats after stopping
        calculateStorageStats()
        
        // Log the recording stop
        NSLog("⚫️ Recording stopped")
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        isPaused = true
        
        // Pause screenshot capture
        ScreenshotManager.shared.pauseCapturing()
        
        // Log the recording pause
        NSLog("⏸️ Recording paused")
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        isPaused = false
        
        // Resume screenshot capture
        ScreenshotManager.shared.resumeCapturing()
        
        // Log the recording resume
        NSLog("▶️ Recording resumed")
    }
    
    // MARK: - Video Recording
    
    func toggleVideoRecording() {
        if isRecordingVideo {
            stopVideoRecording()
        } else {
            startVideoRecording()
        }
    }
    
    func startVideoRecording() {
        isRecordingVideo = true
        // Use correct public method for video recording
        Task {
            await ScreenshotManager.shared.startVideoRecording()
        }
        NotificationCenter.default.post(name: Notification.Name("RecordingStatusChanged"), object: true)
    }
    
    func stopVideoRecording() {
        isRecordingVideo = false
        // Use correct public method for stopping video recording
        Task {
            await ScreenshotManager.shared.stopVideoRecording()
        }
        NotificationCenter.default.post(name: Notification.Name("RecordingStatusChanged"), object: false)
    }
    
    // MARK: - Audio Recording
    
    func toggleAudioRecording() {
        if isRecordingAudio {
            stopAudioRecording()
        } else {
            startAudioRecording()
        }
    }
    
    func startAudioRecording() {
        isRecordingAudio = true
        // Use correct public method for audio recording
        ScreenshotManager.shared.startAudioRecording()
        NotificationCenter.default.post(name: Notification.Name("RecordingStatusChanged"), object: true)
    }
    
    func stopAudioRecording() {
        isRecordingAudio = false
        // Use correct public method for stopping audio recording
        ScreenshotManager.shared.stopAudioRecording()
        NotificationCenter.default.post(name: Notification.Name("RecordingStatusChanged"), object: false)
    }
    
    // Toggle recording state
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // Clear all data - the implementation can be basic for now
    func clearAllData() {
        // If there's no specific implementation yet, we can simply log it
        NSLog("Request to clear all data received")
        
        // Reset storage usage
        storageUsage = StorageUsage()
        storagePercentage = 0.0
        
        // Recalculate stats
        calculateStorageStats()
    }
    
    // Save settings - just a placeholder for now
    func saveSettings() {
        // Save the essential settings to UserDefaults
        UserDefaults.standard.set(aiLocalProcessing, forKey: "aiLocalProcessing")
        UserDefaults.standard.set(recordAudio, forKey: "recordAudio")
        UserDefaults.standard.set(recordVideo, forKey: "recordVideo")
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        
        NSLog("Settings saved")
    }
    
    // Update storage usage - just calls calculateStorageStats
    func updateStorageUsage() {
        calculateStorageStats()
    }
} 