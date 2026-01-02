import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    @UserDefault("showNotifications", defaultValue: true) private var showNotifications: Bool
    private var isNotificationsAvailable = false
    
    private init() {}
    
    // MARK: - Public Methods
    
    func registerForNotifications() {
        // Check if we're in a proper app bundle environment
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("Running in development environment without proper bundle ID, notifications disabled")
            isNotificationsAvailable = false
            return
        }
        
        // Safe to proceed with notification registration
        isNotificationsAvailable = true
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if granted {
                NSLog("Notification permissions granted")
            } else if let error = error {
                NSLog("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
    }
    
    func showNotification(title: String, body: String, identifier: String?) {
        guard showNotifications, isNotificationsAvailable else { 
            // Just log the notification when they can't be displayed
            NSLog("Notification (disabled): \(title) - \(body)")
            return 
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        // Add app identifier to help users identify the source
        content.categoryIdentifier = "autorecall"
        
        // Create a unique identifier for this notification if none provided
        let notificationID = identifier ?? UUID().uuidString
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error posting notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleRecordingReminder(timeInterval: TimeInterval = 3600) {
        guard showNotifications, isNotificationsAvailable else { return }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Still Recording"
        content.body = "AutoRecall has been recording for an hour. Tap to manage recording settings."
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "recording_reminder"
        
        // Trigger after the specified interval
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "recording_reminder",
            content: content,
            trigger: trigger
        )
        
        // Add request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error scheduling reminder: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelRecordingReminder() {
        guard isNotificationsAvailable else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["recording_reminder"])
    }
    
    func showStorageWarning(percentUsed: Double) {
        guard showNotifications, isNotificationsAvailable, percentUsed > 0.8 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Storage Almost Full"
        content.body = "AutoRecall is using \(Int(percentUsed * 100))% of allocated storage. Open preferences to manage storage."
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "storage_warning"
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "storage_warning",
            content: content,
            trigger: trigger
        )
        
        // Add request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Error showing storage warning: \(error.localizedDescription)")
            }
        }
    }
} 