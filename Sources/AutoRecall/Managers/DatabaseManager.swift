import Foundation
import SQLite

// Minimal stub for DatabaseManager to allow compilation
// WARNING: This does not provide actual database functionality.

enum DatabaseError: Error {
    case connectionFailed
    case queryFailed(Error)
    case deleteFailed(Error)
}

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private init() {
        NSLog("⚠️ Initializing STUB DatabaseManager. No data will be saved or loaded.")
    }
    
    // Provide dummy implementations for expected methods
    
    func getScreenshots(for date: Date? = nil, appName: String? = nil, limit: Int = 100) -> [Screenshot] {
        NSLog("⚠️ DatabaseManager STUB: getScreenshots called - returning empty array")
        return []
    }
    
    func getScreenshotsForTimeRange(startDate: Date, endDate: Date) -> [Screenshot] {
        NSLog("⚠️ DatabaseManager STUB: getScreenshotsForTimeRange called - returning empty array")
        return []
    }

    func saveScreenshot(_ screenshot: Screenshot) {
        NSLog("⚠️ DatabaseManager STUB: saveScreenshot called for ID \(screenshot.id) - data NOT saved")
    }
    
    func deleteScreenshot(id: UUID) -> Bool {
        NSLog("⚠️ DatabaseManager STUB: deleteScreenshot called for ID \(id) - returning false")
        return false
    }
    
    func deleteOldScreenshots(olderThan date: Date) throws -> Int {
        NSLog("⚠️ DatabaseManager STUB: deleteOldScreenshots called - returning 0")
        return 0
    }

    func updateOCRText(for path: String, text: String) {
         NSLog("⚠️ DatabaseManager STUB: updateOCRText called for path \(path) - data NOT saved")
    }
    
    func searchScreenshots(query: String, limit: Int = 100) -> [Screenshot] {
        NSLog("⚠️ DatabaseManager STUB: searchScreenshots called for query '\(query)' - returning empty array")
        return []
    }

    func getClipboardItems(limit: Int = 100) -> [Screenshot] {
        NSLog("⚠️ DatabaseManager STUB: getClipboardItems called - returning empty array")
        return []
    }
    
    // Text Input Stubs
    func saveTextInput(text: String, appName: String, windowTitle: String, timestamp: Date, url: String?) {
        NSLog("⚠️ DatabaseManager STUB: saveTextInput called - data NOT saved")
    }

    func getRecentTextInputs(limit: Int = 100) -> [TextInput] {
         NSLog("⚠️ DatabaseManager STUB: getRecentTextInputs called - returning empty array")
        return []
    }

    func getTextInputs(startDate: Date, endDate: Date) -> [TextInput] {
        NSLog("⚠️ DatabaseManager STUB: getTextInputs called - returning empty array")
        return []
    }

    func searchTextInputs(query: String) -> [TextInput] {
        NSLog("⚠️ DatabaseManager STUB: searchTextInputs called for query '\(query)' - returning empty array")
        return []
    }

    func deleteTextInput(id: Int64) {
         NSLog("⚠️ DatabaseManager STUB: deleteTextInput called for ID \(id) - data NOT deleted")
    }

    // Placeholder for other methods potentially called
    func repairAndOptimizeDatabase() -> Bool {
        NSLog("⚠️ DatabaseManager STUB: repairAndOptimizeDatabase called - returning true")
        return true 
    }
    func getDatabaseSize() -> Int64 {
        NSLog("⚠️ DatabaseManager STUB: getDatabaseSize called - returning 0")
        return 0
    }
    func optimizeDatabase() throws {
         NSLog("⚠️ DatabaseManager STUB: optimizeDatabase called - doing nothing")
    }
    func testConnection() -> Bool {
         NSLog("⚠️ DatabaseManager STUB: testConnection called - returning true")
        return true
    }
     func savePendingData() {
         NSLog("⚠️ DatabaseManager STUB: savePendingData called - doing nothing")
    }
     func checkAndRepairClipboardData() {
         NSLog("⚠️ DatabaseManager STUB: checkAndRepairClipboardData called - doing nothing")
    }
     func searchClipboardItems(query: String) -> [ClipboardItem] {
        NSLog("⚠️ DatabaseManager STUB: searchClipboardItems called - returning empty array")
        return []
    }
}
