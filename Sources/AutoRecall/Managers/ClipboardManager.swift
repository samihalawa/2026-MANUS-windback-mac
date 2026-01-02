import Foundation
import AppKit
import UniformTypeIdentifiers
import Vision
import SQLite

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    private let storage = StorageManager.shared
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    @Published var items: [ClipboardItem] = []
    
    // Configuration
    @UserDefault("maxClipboardItems", defaultValue: 100) private var maxItems: Int
    @UserDefault("performOCROnClipboardImages", defaultValue: true) private var performOCROnImages: Bool
    
    // Queue management
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    private let monitoringInterval = 1.0 // Check every second
    private let databaseManager = DatabaseManager.shared
    private let processingQueue = DispatchQueue(label: "com.autorecall.clipboard.processing", qos: .userInitiated)
    private let ocrQueue = DispatchQueue(label: "com.autorecall.clipboard.ocr", qos: .background)
    private let notificationManager = NotificationManager.shared
    
    private init() {
        self.lastChangeCount = pasteboard.changeCount
        loadItems()
        
        // Listen for app termination to clean up resources
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupResources),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func cleanupResources() {
        // Ensure any pending operations are completed
        stopMonitoring()
        
        // Reset items to free memory
        processingQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.items = []
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring the clipboard
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        NSLog("📋 Started clipboard monitoring")
        isMonitoring = true
        
        // Stop any existing timer
        monitoringTimer?.invalidate()
        
        // Create a new timer to check for clipboard changes
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkClipboard()
        }
        
        // Run the timer on the main run loop to ensure it fires even when app is in background
        if let timer = monitoringTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Force an immediate check
        checkClipboard()
    }
    
    /// Force check the clipboard without waiting for the timer
    func checkClipboardManually() {
        // Always process clipboard content, even if the change count hasn't changed
        // This is useful for initializing the clipboard history when the app starts
        NSLog("📋 Manually checking clipboard")
        processClipboardContent()
        
        // Force a refresh of the items
        self.refreshItems()
    }
    
    // MARK: - Save Clipboard Methods

    private func saveClipboardText(_ text: String) {
        let item = ClipboardItem(
            id: UUID(),
            text: text,
            type: .text,
            timestamp: Date(),
            data: nil
        )
        addItem(item)
    }

    private func saveClipboardURL(_ urlString: String) {
        let item = ClipboardItem(
            id: UUID(),
            text: urlString,
            type: .url,
            timestamp: Date(),
            data: nil
        )
        addItem(item)
    }

    private func saveClipboardImage(_ image: NSImage) {
        let item = ClipboardItem(
            id: UUID(),
            text: "Image",
            type: .image,
            timestamp: Date(),
            data: image.tiffRepresentation
        )
        addItem(item)
    }

    private func saveClipboardFileURLs(_ urls: [URL]) {
        let content = urls.map { $0.path }.joined(separator: "\n")
        let item = ClipboardItem(
            id: UUID(),
            text: content,
            type: .file,
            timestamp: Date(),
            data: nil
        )
        addItem(item)
    }

    private func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.items.insert(item, at: 0)
            // Trim to max items
            if self.items.count > self.maxItems {
                self.items = Array(self.items.prefix(self.maxItems))
            }
        }
    }

    /// Create a manual clipboard entry
    func createManualClipboardEntry(content: String, type: ClipboardItemType = .text) {
        NSLog("📋 Creating manual clipboard entry")
        
        switch type {
        case .text:
            saveClipboardText(content)
        case .url:
            saveClipboardURL(content)
        case .image:
            if let image = NSImage(named: "clipboard_placeholder") {
                saveClipboardImage(image)
            } else {
                saveClipboardText("Image: " + content)
            }
        case .file:
            if let url = URL(string: content), FileManager.default.fileExists(atPath: url.path) {
                saveClipboardFileURLs([url])
            } else {
                saveClipboardText("File: " + content)
            }
        default:
            saveClipboardText(content)
        }
        
        // Refresh the items
        self.refreshItems()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        NSLog("📋 Stopped clipboard monitoring")
        isMonitoring = false
        
        // Invalidate the timer
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    func refreshItems() {
        loadItems()
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        // Copy item back to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .image:
            // Load image from file and put it on clipboard
            if let image = loadImageFromPath(for: item.id) {
                pasteboard.writeObjects([image])
                NSLog("📋 Copied image to clipboard")
            } else {
                // If we can't find the image, just copy the text
                pasteboard.setString(item.text ?? "", forType: .string)
                NSLog("📋 Copied text to clipboard (image not found)")
            }
        case .url:
            if let url = URL(string: item.text ?? "") {
                pasteboard.writeObjects([url as NSURL])
                NSLog("📋 Copied URL to clipboard")
            } else {
                pasteboard.setString(item.text ?? "", forType: .string)
                NSLog("📋 Copied text to clipboard (invalid URL)")
            }
        case .file:
            // For file references, we copy the path(s) back to the clipboard
            // as both file URLs and string paths
            let fileURL = URL(fileURLWithPath: item.text ?? "")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                pasteboard.writeObjects([fileURL as NSURL])
                NSLog("📋 Copied file to clipboard")
            } else {
                pasteboard.setString(item.text ?? "", forType: .string)
                NSLog("📋 Copied file path to clipboard (file not found)")
            }
        default:
            pasteboard.setString(item.text ?? "", forType: .string)
            NSLog("📋 Copied text to clipboard")
        }
    }
    
    func deleteItem(_ id: UUID) {
        // Delete from database and filesystem
        let success = storage.deleteScreenshot(id: id)
        
        // Update items array
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == id }
        }
        
        NSLog("📋 Deleted clipboard item: \(success ? "success" : "failed")")
    }
    
    func clearAllItems() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get all items
            let itemsToDelete = self.items
            
            // Delete each item
            for item in itemsToDelete {
                _ = self.storage.deleteScreenshot(id: item.id)
            }
            
            // Update UI
            DispatchQueue.main.async {
                self.items.removeAll()
                NSLog("📋 Cleared all clipboard items")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadItems() {
        // Get clipboard items from database
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let screenshots = self.databaseManager.getClipboardItems(limit: self.maxItems)
            let clipboardItems = screenshots.map { ClipboardItem(from: $0) }
            
            // Update published property on main thread
            DispatchQueue.main.async {
                self.items = clipboardItems
                NSLog("📋 Loaded \(clipboardItems.count) clipboard items")
            }
        }
    }
    
    private func loadImageFromPath(for id: UUID) -> NSImage? {
        // Find the screenshot with this ID
        let screenshots = databaseManager.getScreenshots().filter { $0.id == id }
        guard let screenshot = screenshots.first else { return nil }
        
        // Load the image from the path
        if FileManager.default.fileExists(atPath: screenshot.path) {
            return NSImage(contentsOfFile: screenshot.path)
        }
        return nil
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // If change count hasn't changed, clipboard content is the same
        guard currentChangeCount != lastChangeCount else { return }
        
        // Update the last change count
        lastChangeCount = currentChangeCount
        
        // Process the clipboard content
        processClipboardContent()
    }
    
    private func processClipboardContent() {
        // Get the current clipboard change count
        let currentChangeCount = pasteboard.changeCount
        
        // If the clipboard hasn't changed, don't process it
        if currentChangeCount == lastChangeCount {
            return
        }
        
        // Update the last change count
        lastChangeCount = currentChangeCount
        
        // Process the clipboard content based on available types
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            // Process image from clipboard
            processClipboardImage(image)
        } else if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            // Process URLs from clipboard
            processClipboardURLs(urls)
        } else if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Process string from clipboard
            processClipboardString(string)
        }
        
        // Refresh the items list on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.refreshItems()
        }
    }
    
    private func processClipboardImage(_ image: NSImage) {
        // Create a unique filename for the image
        let timestamp = Date().timeIntervalSince1970
        let filename = "clipboard_image_\(Int(timestamp)).png"
        
        // Get the clipboard directory
        guard let clipboardDir = getClipboardDirectory() else { return }
        let fileURL = clipboardDir.appendingPathComponent(filename)
        
        // Convert NSImage to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            NSLog("📋 Failed to convert clipboard image to PNG")
            return
        }
        
        do {
            // Save the image to a file
            try pngData.write(to: fileURL)
            
            NSLog("📋 Copied image to clipboard")
            
            // Create a screenshot object for the database
            let screenshot = Screenshot(
                id: UUID(),
                path: fileURL.path,
                timestamp: Date(),
                appName: "Clipboard",
                windowTitle: "Image Copy",
                url: nil,
                isClipboardItem: true,
                isTranscription: false,
                ocrText: "clipboard image",
                isVideo: false
            )
            
            // Save to the database
            databaseManager.saveScreenshot(screenshot)
            
            // Perform OCR on the image in the background
            performOCROnImage(fileURL.path, screenshotID: screenshot.id)
            
        } catch {
            NSLog("📋 Failed to save clipboard image: \(error.localizedDescription)")
        }
    }
    
    private func processClipboardURLs(_ urls: [URL]) {
        // Create a file list as text
        let fileList = urls.map { $0.path }.joined(separator: "\n")
        
        // Create a unique filename for the file list
        let timestamp = Date().timeIntervalSince1970
        let filename = "clipboard_files_\(Int(timestamp)).txt"
        
        // Get the clipboard directory
        guard let clipboardDir = getClipboardDirectory() else { return }
        let fileURL = clipboardDir.appendingPathComponent(filename)
        
        do {
            // Save the file list to a text file
            try fileList.write(to: fileURL, atomically: true, encoding: .utf8)
            
            NSLog("📋 Copied \(urls.count) files to clipboard")
            
            // Create a screenshot object for the database
            let screenshot = Screenshot(
                id: UUID(),
                path: fileURL.path,
                timestamp: Date(),
                appName: "Clipboard",
                windowTitle: "File Copy",
                url: nil,
                isClipboardItem: true,
                isTranscription: false,
                ocrText: fileList,
                isVideo: false
            )
            
            // Save to the database
            databaseManager.saveScreenshot(screenshot)
            
        } catch {
            NSLog("📋 Failed to save clipboard file list: \(error.localizedDescription)")
        }
    }
    
    private func processClipboardString(_ string: String) {
        // Create a unique filename for the text
        let timestamp = Date().timeIntervalSince1970
        let filename = "clipboard_text_\(Int(timestamp)).txt"
        
        // Get the clipboard directory
        guard let clipboardDir = getClipboardDirectory() else { return }
        let fileURL = clipboardDir.appendingPathComponent(filename)
        
        do {
            // Save the text to a file
            try string.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Check if it looks like a URL
            let isURL = string.hasPrefix("http://") || string.hasPrefix("https://") || string.hasPrefix("www.")
            if isURL {
                NSLog("📋 Copied URL to clipboard: \(string)")
            } else {
                NSLog("📋 Copied text to clipboard: \(string.prefix(50))...")
            }
            
            // Create a screenshot object for the database
            let screenshot = Screenshot(
                id: UUID(),
                path: fileURL.path,
                timestamp: Date(),
                appName: "Clipboard",
                windowTitle: "Text Copy",
                url: isURL ? string : nil,
                isClipboardItem: true,
                isTranscription: false,
                ocrText: string,
                isVideo: false
            )
            
            // Save to the database
            databaseManager.saveScreenshot(screenshot)
            
        } catch {
            NSLog("📋 Failed to save clipboard text: \(error.localizedDescription)")
        }
    }
    
    private func getClipboardDirectory() -> URL? {
        guard let baseDir = StorageManager.getBaseDirectory() else {
            NSLog("📋 Failed to get base directory for clipboard")
            return nil
        }
        
        let clipboardDir = baseDir.appendingPathComponent("Clipboard", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: clipboardDir.path) {
            do {
                try FileManager.default.createDirectory(at: clipboardDir, withIntermediateDirectories: true, attributes: nil)
                NSLog("📋 Created clipboard directory at: \(clipboardDir.path)")
            } catch {
                NSLog("📋 Failed to create clipboard directory: \(error.localizedDescription)")
                return nil
            }
        }
        
        return clipboardDir
    }
    
    private func performOCROnImage(_ imagePath: String, screenshotID: UUID) {
        // This is just a placeholder - in a real app, you would perform OCR here
        // For now, we'll just update the ocrText field with a placeholder
        DispatchQueue.global(qos: .background).async {
            // Simulate OCR processing time
            Thread.sleep(forTimeInterval: 2.0)
            
            // Update the ocrText field
            self.databaseManager.updateOCRText(for: imagePath, text: "Image content (OCR would extract text here)")
            
            NSLog("📋 OCR performed on clipboard image: \(imagePath)")
        }
    }
    
    private func performOCR(_ image: NSImage, completion: @escaping (String?) -> Void) {
        ocrQueue.async {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                completion(nil)
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    NSLog("OCR error: \(error!.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(nil)
                    return
                }
                
                let text = observations.compactMap { observation -> String? in
                    return observation.topCandidates(1).first?.string
                }.joined(separator: " ")
                
                completion(text.isEmpty ? nil : text)
            }
            
            // Configure the request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                NSLog("OCR error: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    private func trimOldItems() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get all clipboard items sorted by timestamp (newest first)
            let allItems = self.databaseManager.getClipboardItems(limit: 1000)
            
            // If we have more than maxItems, delete the excess
            if allItems.count > self.maxItems {
                // Get the items to delete (the oldest ones)
                let itemsToDelete = allItems.suffix(from: self.maxItems)
                
                for item in itemsToDelete {
                    _ = self.storage.deleteScreenshot(id: item.id)
                    NSLog("📋 Removed old clipboard item: \(item.id)")
                }
                
                // Refresh the items
                DispatchQueue.main.async {
                    self.loadItems()
                }
            }
        }
    }
} 