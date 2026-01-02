import Foundation
import Combine

/// Storage Manager for managing screenshots, videos, and data persistence
class StorageManager {
    static let shared = StorageManager()
    private let fileManager = FileManager.default
    private var screenshotCache: [ScreenshotRecord] = []
    private let cacheQueue = DispatchQueue(label: "com.windback.storage.cache", qos: .utility)

    private init() {
        setupDirectories()
        loadCachedScreenshots()
    }

    // MARK: - Directory Management

    static func getBaseDirectory() -> URL? {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = paths.first else { return nil }
        return appSupport.appendingPathComponent("WindBack", isDirectory: true)
    }

    private static let fileManager = FileManager.default

    func getAppSupportDirectory() -> URL {
        let url = StorageManager.getBaseDirectory() ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WindBack")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func getScreenshotsDirectory() -> URL {
        let url = getAppSupportDirectory().appendingPathComponent("Screenshots", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func getVideosDirectory() -> URL? {
        let url = getAppSupportDirectory().appendingPathComponent("Videos", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func setupDirectories() {
        _ = getScreenshotsDirectory()
        _ = getVideosDirectory()
    }

    // MARK: - Screenshot Management

    func getAllScreenshots() -> [ScreenshotRecord] {
        return cacheQueue.sync { screenshotCache }
    }

    func saveScreenshot(_ screenshot: ScreenshotRecord) {
        cacheQueue.async { [weak self] in
            self?.screenshotCache.append(screenshot)
            self?.persistScreenshotIndex()
        }
    }

    func deleteScreenshot(id: String) -> Bool {
        cacheQueue.sync {
            if let index = screenshotCache.firstIndex(where: { $0.id == id }) {
                let screenshot = screenshotCache.remove(at: index)
                // Delete file
                try? fileManager.removeItem(atPath: screenshot.path)
                persistScreenshotIndex()
                return true
            }
            return false
        }
    }

    func deleteScreenshotsOlderThan(date: Date) -> Bool {
        cacheQueue.sync {
            let before = screenshotCache.count
            screenshotCache.removeAll { $0.timestamp < date }
            persistScreenshotIndex()
            return screenshotCache.count < before
        }
    }

    // MARK: - Persistence

    private func getIndexPath() -> URL {
        return getAppSupportDirectory().appendingPathComponent("screenshots_index.json")
    }

    private func loadCachedScreenshots() {
        let indexPath = getIndexPath()
        guard fileManager.fileExists(atPath: indexPath.path) else { return }

        do {
            let data = try Data(contentsOf: indexPath)
            screenshotCache = try JSONDecoder().decode([ScreenshotRecord].self, from: data)
            NSLog("Loaded \(screenshotCache.count) screenshots from cache")
        } catch {
            NSLog("Failed to load screenshot index: \(error)")
        }
    }

    private func persistScreenshotIndex() {
        do {
            let data = try JSONEncoder().encode(screenshotCache)
            try data.write(to: getIndexPath())
        } catch {
            NSLog("Failed to persist screenshot index: \(error)")
        }
    }
    
    func deleteOldVideos(olderThan date: Date) {
         NSLog("⚠️ StorageManager STUB: deleteOldVideos called - files NOT deleted")
    }

    func calculateScreenshotsStorageSize() -> Int64 {
        NSLog("⚠️ StorageManager STUB: calculateScreenshotsStorageSize called - returning 0")
        return 0
    }

    func calculateVideosStorageSize() -> Int64 {
         NSLog("⚠️ StorageManager STUB: calculateVideosStorageSize called - returning 0")
        return 0
    }

    func formatStorageSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    func cleanupOldData(retentionDays: Int) -> (screenshots: Int, videos: Int) {
        NSLog("⚠️ StorageManager STUB: cleanupOldData called - returning (0, 0)")
        return (0, 0)
    }
    
    // Placeholder for other methods potentially called
    func verifyDataIntegrity() -> Bool {
         NSLog("⚠️ StorageManager STUB: verifyDataIntegrity called - returning true")
        return true
    }
     func findLargeFiles() -> [String] {
         NSLog("⚠️ StorageManager STUB: findLargeFiles called - returning empty array")
        return []
    }
     func cleanupTemporaryFiles() -> Bool {
         NSLog("⚠️ StorageManager STUB: cleanupTemporaryFiles called - returning true")
        return true
    }
     func optimizeStorage() -> Bool {
         NSLog("⚠️ StorageManager STUB: optimizeStorage called - returning true")
        return true
    }
     func testStoragePaths() -> Bool {
         NSLog("⚠️ StorageManager STUB: testStoragePaths called - returning true")
        return true
    }
     func createDataBackup() -> URL? {
         NSLog("⚠️ StorageManager STUB: createDataBackup called - returning nil")
        return nil
    }
} 