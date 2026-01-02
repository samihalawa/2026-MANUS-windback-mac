import Foundation
import AppKit
import SwiftUI
import AVFoundation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    // App state management
    private let appState = AppState.shared
    
    // Permission status trackers
    private var hasScreenRecordingPermission = false
    private var hasAudioPermission = false
    private var hasAccessibilityPermission = false
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for command line arguments before normal app startup
        if processCommandLineArguments() {
            // If command line argument was processed, exit app
            NSApp.terminate(self)
            return
        }
        
        // Register for notifications
        registerForNotifications()
        
        // Initialize managers
        initializeManagers()
        
        // Configure app defaults if first launch
        checkAndSetupFirstLaunch()
        
        // Check permissions
        checkPermissions()
        
        // Set up menu bar
        setupMenuBar()
        
        // If auto-start recording is enabled, start it
        if UserDefaults.standard.bool(forKey: "autoStartRecording") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.hasScreenRecordingPermission {
                    self.startRecording()
                } else {
                    NotificationManager.shared.showNotification(
                        title: "Auto-Start Disabled",
                        body: "Screen recording permission is required for auto-start. Please enable in System Preferences.",
                        identifier: nil
                    )
                }
            }
        }
    }
    
    /// Process command line arguments and return true if any were handled
    private func processCommandLineArguments() -> Bool {
        let args = CommandLine.arguments
        
        // Skip processing if no arguments or just the executable path
        guard args.count > 1 else { return false }
        
        if args.contains("--repair-database") {
            print("Repairing database...")
            let result = DatabaseManager.shared.repairAndOptimizeDatabase()
            print("Database repair \(result ? "succeeded" : "failed")")
            return true
        }
        
        if args.contains("--verify-integrity") {
            print("Verifying data integrity...")
            let result = StorageManager.shared.verifyDataIntegrity()
            print("Data integrity check: found \(result.issues) issues, fix success: \(result.success)")
            return true
        }
        
        if args.contains("--analyze-memory") {
            print("Analyzing memory usage...")
            analyzeMemoryUsage()
            return true
        }
        
        if args.contains("--optimize") {
            print("Optimizing application performance...")
            optimizePerformance()
            return true
        }
        
        if args.contains("--run-tests") {
            print("Running internal tests...")
            runInternalTests()
            return true
        }
        
        return false
    }
    
    private func analyzeMemoryUsage() {
        // Current memory usage
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Float(taskInfo.resident_size) / 1048576.0
            print("Current memory usage: \(String(format: "%.2f", usedMB)) MB")
        }
        
        // Check for potential memory issues in the database
        let dbSize = DatabaseManager.shared.getDatabaseSize()
        print("Database size: \(String(format: "%.2f", Double(dbSize) / 1048576.0)) MB")
        
        // Check for large screenshots
        let largeScreenshots = StorageManager.shared.findLargeFiles(sizeThreshold: 5 * 1024 * 1024)
        if !largeScreenshots.isEmpty {
            print("Found \(largeScreenshots.count) large screenshot files that may impact memory usage")
        }
        
        print("Memory analysis completed.")
    }
    
    private func optimizePerformance() {
        print("Optimizing database...")
        let dbOptimized = DatabaseManager.shared.optimizeDatabase()
        print("Database optimization \(dbOptimized ? "succeeded" : "failed")")
        
        print("Cleaning up temporary files...")
        let tempCleaned = StorageManager.shared.cleanupTemporaryFiles()
        print("Temporary files cleanup \(tempCleaned ? "succeeded" : "failed")")
        
        print("Optimizing storage...")
        let storageCleaned = StorageManager.shared.optimizeStorage()
        print("Storage optimization \(storageCleaned ? "succeeded" : "failed")")
        
        print("Performance optimization completed.")
    }
    
    private func runInternalTests() {
        print("Running internal tests...")
        
        // Test database connection
        if DatabaseManager.shared.testConnection() {
            print("✓ Database connection test passed")
        } else {
            print("✗ Database connection test failed")
        }
        
        // Test storage paths
        if StorageManager.shared.testStoragePaths() {
            print("✓ Storage paths test passed")
        } else {
            print("✗ Storage paths test failed")
        }
        
        print("Internal tests completed.")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop recording if active
        if appState.isRecording {
            ScreenshotManager.shared.stopCapturing()
        }
        
        // Save any pending data
        DatabaseManager.shared.savePendingData()
        
        // Notify user
        NotificationManager.shared.showNotification(
            title: "AutoRecall Closed",
            body: "AutoRecall has been closed. Recording has stopped.",
            identifier: nil
        )
    }
    
    // MARK: - Initialization Methods
    
    private func initializeManagers() {
        // Initialize storage and database
        _ = StorageManager.shared
        _ = DatabaseManager.shared
        
        // Initialize notification manager
        _ = NotificationManager.shared
        
        // Initialize screenshot manager
        _ = ScreenshotManager.shared
        
        // Initialize and start clipboard monitoring if enabled
        if UserDefaults.standard.bool(forKey: "monitorClipboard") {
            ClipboardManager.shared.startMonitoring()
            NSLog("📋 Started clipboard monitoring at app launch")
        } else {
            NSLog("📋 Clipboard monitoring disabled (can be enabled in settings)")
        }
        
        // Initialize AI manager if enabled
        if UserDefaults.standard.bool(forKey: "aiFeatureEnabled") {
            _ = AIManager.shared
        }
        
        // Repair database, verify data integrity, and cleanup storage if needed
        DispatchQueue.global(qos: .utility).async {
            // First clean up storage
            StorageManager.shared.cleanupStorage()
            
            // Then repair database
            if DatabaseManager.shared.repairAndOptimizeDatabase() {
                NSLog("✅ Database repaired and optimized successfully")
            }
            
            // Specifically repair clipboard data
            if DatabaseManager.shared.checkAndRepairClipboardData() {
                NSLog("✅ Clipboard data verified and repaired successfully")
            }
            
            // Verify data integrity and fix issues
            let integrityResult = StorageManager.shared.verifyDataIntegrity()
            if integrityResult.issues > 0 {
                NSLog("⚠️ Data integrity check found and fixed \(integrityResult.issues) issues")
                
                // Create a backup if issues were found and fixed
                if integrityResult.success {
                    if let backupURL = StorageManager.shared.createDataBackup() {
                        DispatchQueue.main.async {
                            self.showBackupCreatedMessage(at: backupURL)
                        }
                    }
                }
            } else {
                NSLog("✅ Data integrity check passed with no issues")
            }
        }
    }
    
    private func checkAndSetupFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // Set default preferences for first launch
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            UserDefaults.standard.set(true, forKey: "recordAudio")
            UserDefaults.standard.set(false, forKey: "recordVideo")
            UserDefaults.standard.set(3.0, forKey: "captureInterval")
            UserDefaults.standard.set(true, forKey: "showInDock")
            UserDefaults.standard.set(false, forKey: "autoStartRecording")
            UserDefaults.standard.set(true, forKey: "aiFeatureEnabled")
            
            // Show welcome notification on first launch
            NotificationManager.shared.showNotification(
                title: "AutoRecall Ready",
                body: "AutoRecall is now set up and ready to use. Check preferences to customize your experience.",
                identifier: nil
            )
        }
    }
    
    private func setupMenuBar() {
        // Directly access the singleton
        MenuBarManager.shared.updateIcon()
    }
    
    // MARK: - Permission Management
    
    private func checkPermissions() {
        // Check screen recording permission
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        
        // Check audio permission - macOS has no direct audio permission API like iOS
        // We'll assume true or implement a real check for audio devices
        hasAudioPermission = true
        
        // Check accessibility permission
        hasAccessibilityPermission = AXIsProcessTrusted()
        
        // Log permission status
        NSLog("Permissions - Screen Recording: \(hasScreenRecordingPermission), Audio: \(hasAudioPermission), Accessibility: \(hasAccessibilityPermission)")
        
        // Update app state with permissions
        appState.hasRequiredPermissions = hasScreenRecordingPermission
        
        // Show permission message if needed
        if !hasScreenRecordingPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPermissionRequiredMessage()
            }
        }
    }
    
    private func showPermissionRequiredMessage() {
        // Check if we've already asked recently
        let lastAskedTime = UserDefaults.standard.double(forKey: "lastPermissionDialogTime")
        let currentTime = Date().timeIntervalSince1970
        
        // Don't ask again if we've asked within the last 24 hours
        if lastAskedTime > 0 && (currentTime - lastAskedTime) < 86400 {
            NSLog("Skipping permission dialog - already asked within 24 hours")
            return
        }
        
        // Don't show if user has opted out
        if UserDefaults.standard.bool(forKey: "dontShowPermissionDialog") {
            NSLog("Skipping permission dialog - user opted out")
            return
        }
        
        // Record that we asked
        UserDefaults.standard.set(currentTime, forKey: "lastPermissionDialogTime")
        
        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = "AutoRecall requires screen recording permission to function properly. Would you like to enable this permission now?"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Don't Ask Again")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Security & Privacy
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        } else if response == .alertThirdButtonReturn {
            // User doesn't want to be asked again
            UserDefaults.standard.set(true, forKey: "dontShowPermissionDialog")
        }
    }
    
    // MARK: - Notification Registration
    
    private func registerForNotifications() {
        // Check if we're in a proper app bundle environment
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("Running in development environment without proper bundle ID, notifications disabled")
            return
        }
        
        // Register for notifications
        UNUserNotificationCenter.current().delegate = self
        
        // Register for app reopen notification (clicking dock icon)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReopenApp),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleReopenApp() {
        // Recheck permissions when app is reopened, especially after returning from System Settings
        checkPermissions()
        
        // If permission is now granted and we've recently asked, let the user know it worked
        if hasScreenRecordingPermission && UserDefaults.standard.double(forKey: "lastPermissionDialogTime") > 0 {
            let lastAskedTime = UserDefaults.standard.double(forKey: "lastPermissionDialogTime")
            let currentTime = Date().timeIntervalSince1970
            
            // Only show success if we asked within the last 5 minutes
            if (currentTime - lastAskedTime) < 300 {
                NotificationManager.shared.showNotification(
                    title: "Screen Recording Enabled",
                    body: "Screen recording permission has been successfully granted. You can now use all features of AutoRecall.",
                    identifier: nil
                )
                
                // Store that permission was granted so we don't keep checking
                UserDefaults.standard.set(true, forKey: "screenCapturePermissionGranted")
                
                // Reset last asked time
                UserDefaults.standard.set(0, forKey: "lastPermissionDialogTime")
            }
        }
    }
    
    // MARK: - Recording Control
    
    private func startRecording() {
        if hasScreenRecordingPermission {
            appState.isRecording = true
            ScreenshotManager.shared.startCapturing()
            
            NSLog("Recording started successfully")
        } else {
            // Show permission message
            showPermissionRequiredMessage()
            NSLog("Recording failed to start - missing permissions")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show notifications in-app
        completionHandler([.banner, .sound])
    }
    
    // Handle global search shortcut
    @objc func handleGlobalSearchShortcut() {
        // Activate the app and display the global search interface
        NSApplication.shared.activate(ignoringOtherApps: true)
        // Post a notification that the app can listen for to bring up the search UI
        NotificationCenter.default.post(name: Notification.Name("ActivateGlobalSearch"), object: nil)
        
        NSLog("Global search shortcut activated")
    }
    
    private func showBackupCreatedMessage(at backupURL: URL) {
        // Show notification that backup was created
        NotificationManager.shared.showNotification(
            title: "Data Backup Created",
            body: "A backup of your data has been created due to data integrity repairs.",
            identifier: nil
        )
        
        // Optionally show an alert with more details
        let alert = NSAlert()
        alert.messageText = "Data Backup Created"
        alert.informativeText = "Some data integrity issues were found and fixed. A backup of your data has been created at:\n\n\(backupURL.path)"
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Show the backup in Finder
            NSWorkspace.shared.selectFile(backupURL.path, inFileViewerRootedAtPath: backupURL.deletingLastPathComponent().path)
        }
    }
}

// MARK: - Launch at Login Manager

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private init() {}
    
    func setLaunchAtLogin(_ enabled: Bool) {
        // In a real implementation, this would use SMAppService or a framework like LaunchAtLogin
        // For now, just log the request
        NSLog("Launch at login set to: \(enabled)")
    }
}

// MARK: - Screenshot Manager
// The ScreenshotManager class is now fully implemented in ScreenshotManager.swift
// The duplicate implementation has been removed to fix compilation errors 