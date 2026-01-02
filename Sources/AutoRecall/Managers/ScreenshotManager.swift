import Foundation
import AVFoundation
import CoreGraphics
import AppKit
import Vision
import SwiftUI
import Combine
import ScreenCaptureKit
import CommonCrypto

class ScreenshotManager: NSObject {
    static let shared = ScreenshotManager()
    
    private var isCapturing = false
    private var captureTimer: Timer?
    private var captureStartTime: Date?
    private var displayLink: CVDisplayLink?
    
    // Audio recording properties
    private var audioRecorder: AVAudioRecorder?
    private var isRecordingAudio = false
    private var currentAudioFileName: String?
    
    // Video recording properties
    private var videoRecorder: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var captureEngine: SCStreamCaptureEngine?
    private var captureStream: SCStream?
    private var isRecordingVideo = false
    
    @UserDefault("captureInterval", defaultValue: 3.0) private var captureInterval: Double
    @UserDefault("similarityThreshold", defaultValue: 0.95) private var similarityThreshold: Double
    @UserDefault("recordAudio", defaultValue: true) private var recordAudio: Bool
    @UserDefault("recordVideo", defaultValue: false) private var recordVideo: Bool
    @UserDefault("imageCompressionLevel", defaultValue: 0.8) private var imageCompressionLevel: Double
    @UserDefault("useHEICFormatIfAvailable", defaultValue: true) private var useHEICFormatIfAvailable: Bool
    @UserDefault("screenshotResolutionFactor", defaultValue: 1.0) private var screenshotResolutionFactor: Double
    @UserDefault("maxClipboardItems", defaultValue: 100) private var maxClipboardItems: Int
    
    private let screenshotQueue = DispatchQueue(label: "com.autorecall.screenshot", qos: .utility)
    private let analysisQueue = DispatchQueue(label: "com.autorecall.analysisQueue", qos: .utility)
    private let dbQueue = DispatchQueue(label: "com.autorecall.database", qos: .background)
    
    private let imageCache = NSCache<NSString, NSImage>()
    private var lastScreenshotHash: String?
    private var lastClipboardHash: String?
    
    private let storage = StorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // OCR processing queue
    private let ocrQueue = DispatchQueue(label: "com.autorecall.ocrQueue", qos: .utility)
    
    // Add the missing lastCapturedImage property
    private var lastCapturedImage: NSImage?
    private var lastScreenshotTimestamp: Date?
    
    private let databaseManager = DatabaseManager.shared
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    
    private override init() {
        self.lastChangeCount = pasteboard.changeCount
        // Set up capacity limits for caches
        imageCache.countLimit = 20
        super.init()
    }
    
    // MARK: - Capturing Methods
    
    func startCapturing() {
        guard !isCapturing else { 
            NSLog("Capture already in progress, not starting again")
            return 
        }
        
        NSLog("⭐️ Starting screen capture with interval: \(captureInterval) seconds")
        isCapturing = true
        captureStartTime = Date()
        
        // Verify screen recording permissions before starting
        checkScreenCapturePermission { hasPermission in
            guard hasPermission else {
                NSLog("❌ Screen recording permission denied!")
                DispatchQueue.main.async {
                    NotificationManager.shared.showNotification(
                        title: "Permission Required",
                        body: "Screen recording permission is needed. Please enable in System Preferences."
                    )
                }
                self.isCapturing = false
                return
            }
            
            NSLog("✅ Screen recording permission granted, starting capture timer")
            
            // Schedule timer for regular captures with selector method (more reliable)
            DispatchQueue.main.async {
                self.captureTimer = Timer.scheduledTimer(
                    timeInterval: self.captureInterval,
                    target: self,
                    selector: #selector(self.captureScreenTimer),
                    userInfo: nil,
                    repeats: true
                )
                
                // Make sure timer stays valid even during scrolling
                RunLoop.current.add(self.captureTimer!, forMode: .common)
            
            // Capture immediately on start
                self.captureScreenTimer()
            
            // Start audio recording if enabled
            if self.recordAudio {
                self.startAudioRecording()
            }
            
            // Start video recording if enabled
            if self.recordVideo {
                Task {
                    await self.startVideoRecording()
                }
            }
            
            // Schedule a reminder notification after an hour
            NotificationManager.shared.scheduleRecordingReminder()
            
            // Post notification that recording has started
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordingStatusChanged"), 
                object: true
            )
            }
        }
    }
    
    func stopCapturing() {
        guard isCapturing else { return }
        
        NSLog("Stopping screen capture")
        isCapturing = false
        
        // Invalidate timer
        captureTimer?.invalidate()
        captureTimer = nil
        
        // Stop audio recording if active
        if isRecordingAudio {
            stopAudioRecording()
        }
        
        // Stop video recording if active
        if isRecordingVideo {
            Task {
                await stopVideoRecording()
            }
        }
        
        // Cancel reminder notification
        NotificationManager.shared.cancelRecordingReminder()
        
        NSLog("Screen recording stopped")
        
        // Post notification that recording has stopped
        NotificationCenter.default.post(
            name: NSNotification.Name("RecordingStatusChanged"), 
            object: false
        )
    }
    
    func pauseCapturing() {
        // Temporarily pause capture
        captureTimer?.invalidate()
        captureTimer = nil
        
        NSLog("Screen recording paused")
    }
    
    func resumeCapturing() {
        // Resume capture if it was active
        if isCapturing && captureTimer == nil {
            captureTimer = Timer.scheduledTimer(
                timeInterval: captureInterval,
                target: self,
                selector: #selector(captureScreenTimer),
                userInfo: nil,
                repeats: true
            )
            
            NSLog("Screen recording resumed")
        }
    }
    
    @objc func captureScreenTimer() {
        NSLog("⏱️ Timer fired to capture screen")
        captureCurrentScreen()
    }
    
    private func captureScreenImage(_ screen: NSScreen) -> CGImage? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        
        // Use autoreleasepool to prevent memory leaks with CGImage objects
        return autoreleasepool {
            // Use the appropriate API to get the CGImage
            return CGDisplayCreateImage(displayID)
        }
    }
    
    private func isSimilarToLastScreenshot(_ newImage: NSImage) -> Bool {
        guard let lastImage = lastCapturedImage else {
            return false
        }
        
        // Get the current similarity threshold
        let similarityThreshold = UserDefaults.standard.double(forKey: "similarityThreshold")
        
        // Adjust the threshold slightly to prevent excessive skipping
        let adjustedThreshold = max(0.85, min(similarityThreshold, 0.97))
        
        return calculateImageSimilarity(lastImage, newImage) >= adjustedThreshold
    }
    
    private func generateImageHash(_ image: NSImage) -> String? {
        // Simple implementation - in a real app would use perceptual hashing
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let downsized = resizeImage(bitmap, toSize: NSSize(width: 16, height: 16)),
              let data = downsized.representation(using: .jpeg, properties: [:]) else {
            return nil
        }
        
        return data.md5String
    }
    
    private func resizeImage(_ image: NSBitmapImageRep, toSize size: NSSize) -> NSBitmapImageRep? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        image.draw(in: rect)
        
        newImage.unlockFocus()
        
        return NSBitmapImageRep(data: newImage.tiffRepresentation ?? Data())
    }
    
    private func calculateHashSimilarity(_ hash1: String, _ hash2: String) -> Double {
        // Simple similarity check based on string equality
        // In a real app, would use Hamming distance or other similarity metrics
        if hash1 == hash2 {
            return 1.0
        }
        
        // Calculate approximate similarity based on common characters
        let set1 = Set(hash1)
        let set2 = Set(hash2)
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        
        return Double(intersection) / Double(union)
    }
    
    // MARK: - Saving and Processing
    
    private func saveScreenshot(image: NSImage) {
        screenshotQueue.async {
            // Retry mechanism for failed screenshots
            var retryCount = 0
            let maxRetries = 3
            
            func attemptSave() {
                autoreleasepool {
                    // Create timestamp for this screenshot
                    let timestamp = Date()
                    self.lastScreenshotTimestamp = timestamp
                    
                    // Get app and window info
                    let appName = self.getCurrentAppName()
                    let windowTitle = self.getCurrentWindowTitle()
                    let url = self.getCurrentURL()
                    
                    // Generate a unique filename
                    let filename = "\(Int(timestamp.timeIntervalSince1970))_\(UUID().uuidString).png"
                    
                    if let screenshotDir = self.storage.getScreenshotDirectory(for: timestamp) {
                        let path = screenshotDir.appendingPathComponent(filename).path
                        
                        // Ensure path is valid and not empty
                        guard !path.isEmpty else {
                            NSLog("❌ Cannot save screenshot with empty path")
                return
                        }
                        
                        var success = false
                        var savedPath = path
                        
                        // Try HEIC if available and enabled
                        if #available(macOS 10.13, *), UserDefaults.standard.bool(forKey: "useHEICFormatIfAvailable") {
                            let heicPath = path.replacingOccurrences(of: ".png", with: ".heic")
                            success = self.saveAsHEIC(image, path: heicPath)
                            
                            if success {
                                savedPath = heicPath
                            }
                        }
                        
                        // Fall back to PNG if HEIC failed or not available
                        if !success {
                            // Get compression level from user defaults
                            let compressionLevel = UserDefaults.standard.double(forKey: "imageCompressionLevel")
                            success = self.saveAsPNG(image, path: path, compressionLevel: compressionLevel)
                        }
                        
                        if success {
                            // Create a record
                            let screenshot = Screenshot(
                                id: UUID(),
                                path: savedPath,
                                timestamp: timestamp,
                                appName: appName,
                                windowTitle: windowTitle,
                                url: url,
                                isClipboardItem: false,
                                isTranscription: false,
                                ocrText: "",
                                isVideo: false
                            )
                            
                            // Save record to database
                            self.storage.saveScreenshot(screenshot)
                            
                            // Perform OCR on the image
                            self.performOCR(image) { ocrText in
                                if let text = ocrText {
                                    self.storage.updateOCRText(for: savedPath, text: text)
                                }
                            }
                        } else if retryCount < maxRetries {
                            retryCount += 1
                            NSLog("⚠️ Retrying screenshot save (attempt \(retryCount) of \(maxRetries))")
                            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                                attemptSave()
                            }
                        } else {
                            NSLog("❌ Failed to save screenshot after \(maxRetries) attempts")
                        }
                    } else {
                        NSLog("❌ Could not get screenshot directory")
                    }
                }
            }
            
            attemptSave()
        }
    }
    
    private func saveScreenshotToDatabase(timestamp: Date, filename: String, path: String, image: NSImage) {
        // Generate thumbnail
            if let thumbnail = generateThumbnail(from: image) {
            // Create thumbnail filename
            let thumbnailFilename = "thumb_\(filename)"
            let thumbnailPath = URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(thumbnailFilename).path
            
            // Save thumbnail
                if let thumbnailData = thumbnail.pngRepresentation() {
                do {
                    try thumbnailData.write(to: URL(fileURLWithPath: thumbnailPath))
                    NSLog("✅ Saved thumbnail to: \(thumbnailFilename)")
                    
                    // Create a record
                    let screenshot = Screenshot(
                        id: UUID(),
                        path: path,
                timestamp: timestamp,
                        appName: getCurrentAppName(),
                        windowTitle: getCurrentWindowTitle(),
                        url: getCurrentURL(),
                        isClipboardItem: false,
                        isTranscription: false,
                        ocrText: "",
                        isVideo: false
                    )
                    
                    // Save record to database
                    self.storage.saveScreenshot(screenshot)
                    
                    // Perform OCR on the image
                    self.performOCR(image) { ocrText in
                        if let text = ocrText {
                            self.storage.updateOCRText(for: path, text: text)
                        }
                    }
        } catch {
                    NSLog("❌ Error saving thumbnail: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveAsPNG(_ image: NSImage, path: String, compressionLevel: Double = 0.8) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSLog("❌ Failed to convert NSImage to CGImage")
            return false
        }
        
        // Check if we should downscale the image based on resolution factor
        let resolutionFactor = UserDefaults.standard.double(forKey: "screenshotResolutionFactor")
        let effectiveResolutionFactor = (resolutionFactor >= 0.5) ? resolutionFactor : 0.8
        
        // Apply resolution scaling if needed
        var imageToSave = cgImage
        if effectiveResolutionFactor < 0.99 {
            let originalWidth = cgImage.width
            let originalHeight = cgImage.height
            let newWidth = Int(Double(originalWidth) * effectiveResolutionFactor)
            let newHeight = Int(Double(originalHeight) * effectiveResolutionFactor)
            
            if let context = CGContext(data: nil,
                                     width: newWidth,
                                     height: newHeight,
                                     bitsPerComponent: 8,
                                     bytesPerRow: 0,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
                
                context.interpolationQuality = .high
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                
                if let resizedImage = context.makeImage() {
                    imageToSave = resizedImage
                    NSLog("📏 Resized image from \(originalWidth)x\(originalHeight) to \(newWidth)x\(newHeight)")
                }
            }
        }
        
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            NSLog("❌ Failed to create image destination")
            return false
        }
        
        // Set compression level from UserDefaults or use default
        let compressionFactor = UserDefaults.standard.value(forKey: "ImageCompressionFactor") as? Double ?? compressionLevel
        
        // Enhanced compression options for PNG
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionFactor,
            kCGImagePropertyPNGCompressionFilter: 2, // Adaptive filtering
            kCGImagePropertyPNGInterlaceType: 0, // No interlacing for smaller size
            kCGImageDestinationOptimizeColorForSharing: true
        ]
        
        CGImageDestinationAddImage(destination, imageToSave, options as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            NSLog("✅ PNG file saved to \(url.path) with compression level: \(compressionFactor) and resolution factor: \(effectiveResolutionFactor)")
            return true
        } else {
            NSLog("❌ Failed to save PNG file to \(url.path)")
            return false
        }
    }
    
    private func saveAsHEIC(_ image: NSImage, path: String) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSLog("Failed to convert NSImage to CGImage")
            return false
        }
        
        guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.heic.identifier as CFString, 1, nil) else {
            NSLog("Failed to create HEIC image destination")
            return false
        }
        
        // Get compression level from user defaults (for more control)
        let userCompressionLevel = UserDefaults.standard.double(forKey: "imageCompressionLevel")
        
        // Advanced HEIC compression settings - higher compression efficiency
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.5, userCompressionLevel - 0.2), // Adjust based on user setting
            // kCGImagePropertyHEICSingleTileImage: true, // Comment out unavailable property
            kCGImagePropertyIsFloat: false,
            kCGImagePropertyHasAlpha: false,
            kCGImageDestinationOptimizeColorForSharing: true,
            kCGImageDestinationBackgroundColor: CGColor(gray: 1.0, alpha: 1.0)
        ]
        
        CGImageDestinationSetProperties(destination, options as CFDictionary)
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            NSLog("✅ Successfully saved HEIC screenshot to: \(path) with compression level: \(max(0.5, userCompressionLevel - 0.2))")
            return true
        } else {
            NSLog("❌ Failed to save HEIC image")
            return false
        }
    }
    
    private func resizeImage(_ image: NSImage, byFactor factor: Double) -> NSImage {
        let newWidth = image.size.width * factor
        let newHeight = image.size.height * factor
        
        let resizedImage = NSImage(size: NSSize(width: newWidth, height: newHeight))
        resizedImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight),
                  from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
                  operation: .copy,
                  fraction: 1.0)
        
        resizedImage.unlockFocus()
        return resizedImage
    }
    
    private func generateThumbnail(from image: NSImage) -> NSImage? {
        // Create a smaller thumbnail for faster loading
        let maxDimension: CGFloat = 320
        let originalSize = image.size
        
        // Calculate aspect ratio
        let widthRatio = maxDimension / originalSize.width
        let heightRatio = maxDimension / originalSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Calculate new size
        let scaledWidth = originalSize.width * scaleFactor
        let scaledHeight = originalSize.height * scaleFactor
        
        // Create thumbnail
        let thumbnail = NSImage(size: NSSize(width: scaledWidth, height: scaledHeight))
        thumbnail.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight),
                  from: NSRect(x: 0, y: 0, width: originalSize.width, height: originalSize.height),
                  operation: .copy,
                  fraction: 1.0)
        
        thumbnail.unlockFocus()
        return thumbnail
    }
    
    // MARK: - Analysis
    
    private func analyzeScreenshot(_ image: NSImage, timestamp: Date) {
        // Queue the analysis to run in the background
        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Extract text with OCR
            self.performOCR(image) { ocrText in
                // Extract active window information (in a real app)
                // Get active application name
                let appName = NSWorkspace.shared.frontmostApplication?.localizedName
                
                // Get window title (simplified example - in a real app this would use accessibility APIs)
                let windowTitle = "Unknown Window" // Placeholder
                
                // Get URL if browser is active (simplified example)
                var urlString: String?
                if appName == "Safari" || appName == "Google Chrome" || appName == "Firefox" {
                    // In a real implementation, this would use browser-specific APIs or accessibility
                    urlString = "https://example.com" // Placeholder
                }
                
                // Update database with analysis results
                if let screenshotID = self.lastScreenshotHash {
                    // Generate filename using timestamp
                    let timeStampValue = Int(timestamp.timeIntervalSince1970)
                    _ = "screen_0_\(timeStampValue).png"
                    
                    // Create a record
                    let screenshot = Screenshot(
                        id: UUID(uuidString: screenshotID) ?? UUID(),
                        path: "", // This would be filled in by a real implementation
                        timestamp: timestamp,
                        appName: appName ?? "Unknown",
                        windowTitle: windowTitle,
                        url: urlString,
                        isClipboardItem: false,
                        isTranscription: false,
                        ocrText: ocrText ?? "",
                        isVideo: false
                    )
                    
                    // Save record to database
                    self.storage.saveScreenshot(screenshot)
                }
            }
        }
    }
    
    private func performOCR(_ image: NSImage, completion: @escaping (String?) -> Void) {
        // Use a background queue for OCR processing
        ocrQueue.async {
            autoreleasepool {
                // Resize image for OCR if it's too large (improves performance)
                let processImage = self.prepareImageForOCR(image)
                
                if let cgImage = processImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    let request = VNRecognizeTextRequest { request, error in
                        guard error == nil,
                              let observations = request.results as? [VNRecognizedTextObservation] else {
                            completion(nil)
                            return
                        }
                        
                        // Extract text from observations with confidence filtering
                        let recognizedText = observations.compactMap { observation -> String? in
                            guard let candidate = observation.topCandidates(1).first,
                                  candidate.confidence > 0.3 else { // Filter low confidence results
                                return nil
                            }
                            return candidate.string
                        }.joined(separator: "\n")
                        
                        // Only return text if we have meaningful content
                        if recognizedText.count > 3 {
                            completion(recognizedText)
                        } else {
                            completion(nil)
                        }
                    }
                    
                    // Configure request for better results
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.recognitionLanguages = ["en-US"]
                    request.customWords = ["AutoRecall"] // Add app-specific terms
                    
                    // Set revision to latest for best results
                    if #available(macOS 13.0, *) {
                        request.revision = VNRecognizeTextRequestRevision3
                    } else {
                        request.revision = VNRecognizeTextRequestRevision2
                    }
                    
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        NSLog("❌ OCR error: \(error.localizedDescription)")
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // Prepare image for optimal OCR processing
    private func prepareImageForOCR(_ image: NSImage) -> NSImage {
        // If image is very large, resize it for better OCR performance
        let maxDimension: CGFloat = 2048
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let widthRatio = maxDimension / image.size.width
            let heightRatio = maxDimension / image.size.height
            let scaleFactor = min(widthRatio, heightRatio)
            
            return resizeImage(image, byFactor: scaleFactor)
        }
        
        return image
    }
    
    // MARK: - Audio Recording Methods
    
    public func startAudioRecording() {
        // AVAudioSession is unavailable on macOS, implement a stub for recording
        // In a real implementation, we would use Core Audio for macOS
        NSLog("Audio recording is not implemented on macOS in this version")
        
        // Create unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "audio_recording_\(timestamp).m4a"
        currentAudioFileName = filename
        
        // Get path for audio file
        let documentsDir = storage.getScreenshotsDirectory()
        let audioURL = documentsDir.appendingPathComponent(filename)
        
        // Stub implementation
        isRecordingAudio = true
        NSLog("Started audio recording simulation: \(audioURL.path)")
    }
    
    public func stopAudioRecording() {
        guard isRecordingAudio else { return }
        
        audioRecorder?.stop()
        isRecordingAudio = false
        
        // Save record of the audio recording if filename exists
        if let filename = currentAudioFileName {
            // Get audio file path
            let documentsDir = storage.getScreenshotsDirectory()
            let audioPath = documentsDir.appendingPathComponent(filename)
            
            // Create a screenshot record
            let screenshot = Screenshot(
                id: UUID(),
                path: audioPath.path,
                timestamp: Date(),
                appName: "AutoRecall",
                windowTitle: "Audio Recording",
                url: nil,
                isClipboardItem: false,
                isTranscription: true,
                ocrText: "[Audio Recording]",
                isVideo: false
            )
            
            // Save record to database
            storage.saveScreenshot(screenshot)
            
            NSLog("Saved audio recording: \(audioPath.path)")
            currentAudioFileName = nil
        }
        
        // Remove AVAudioSession call since it's unavailable on macOS
    }
    
    // MARK: - Video Recording Methods
    
    public func startVideoRecording() async {
        do {
            // Create a video configuration to capture the main display
            let config = SCStreamConfiguration()
            config.capturesAudio = false // We handle audio separately
            config.width = Int(NSScreen.main?.frame.width ?? 1920)
            config.height = Int(NSScreen.main?.frame.height ?? 1080)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
            config.queueDepth = 5
            
            // Get available content to capture
            let content = try await SCShareableContent.current
            
            // Find main display
            guard let display = content.displays.first else {
                NSLog("No display found for screen recording")
                return
            }
            
            // Create a filter for the display
            let filter = SCContentFilter(display: display, excludingWindows: [])
            
            // Create capture stream with the filter
            if #available(macOS 12.3, *) {
                // Just create the stream directly without try
                captureStream = SCStream(filter: filter, configuration: config, delegate: nil)
                if captureStream == nil {
                    NSLog("❌ Failed to create screen capture stream")
                    return
                }
            } else {
                // Fallback code...
            }
            
            // Create a capture engine to process frames
            guard let stream = captureStream else {
                NSLog("❌ No capture stream available")
                return
            }
            captureEngine = SCStreamCaptureEngine(stream: stream, configuration: config)
            
            // Set up video writer
            setupVideoWriter()
            
            // Add stream output
            guard let engine = captureEngine else {
                NSLog("❌ Failed to create capture engine")
                return
            }
            try stream.addStreamOutput(engine, type: .screen, sampleHandlerQueue: DispatchQueue.global())
            
            // Start capture
            try await stream.startCapture()
            
            isRecordingVideo = true
            NSLog("Started video recording")
        } catch {
            NSLog("Failed to start video recording: \(error.localizedDescription)")
        }
    }
    
    private func setupVideoWriter() {
        // Create a unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "video_recording_\(timestamp).mp4"
        
        // Get path for the video file
        let documentsDir = storage.getScreenshotsDirectory()
        let videoURL = documentsDir.appendingPathComponent(filename)
        
        NSLog("Video will be recorded to: \(videoURL.path)")
        
        // Note: In a real implementation, we would set up AVAssetWriter here
        // For now, this is a placeholder to make compilation succeed
    }
    
    public func stopVideoRecording() async {
        guard isRecordingVideo else { return }
        
        // Stop the capture
        try? await captureStream?.stopCapture()
        captureStream = nil
        captureEngine = nil
        
        // Finish writing with proper completion handling
        videoInput?.markAsFinished()
        
        // Add timeout handling for finishWriting
        let finishGroup = DispatchGroup()
        finishGroup.enter()
        
        // Mark as no longer recording
            self.videoRecorder = nil
            self.videoInput = nil
            self.isRecordingVideo = false
            finishGroup.leave()
        
        // Wait for finish to complete without using wait()
        var timeoutTask: DispatchWorkItem?
        let timeoutWorkItem = DispatchWorkItem {
            NSLog("⚠️ Timed out waiting for recording to finish")
        }
        timeoutTask = timeoutWorkItem
        DispatchQueue.global().asyncAfter(deadline: .now() + 6, execute: timeoutWorkItem)

        // Set up notification for completion
        finishGroup.notify(queue: .global()) {
            timeoutTask?.cancel()
            NSLog("✅ Recording finished successfully")
        }
    }
    
    // MARK: - Utility functions
    
    func getScreenshotFileSize() -> UInt64 {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            NSLog("❌ Could not get application support directory")
            return 0
        }
        let screenshotsFolder = appSupportURL.appendingPathComponent("AutoRecall/Screenshots")
        
        return calculateDirectorySize(screenshotsFolder.path)
    }
    
    private func calculateDirectorySize(_ path: String) -> UInt64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: UInt64 = 0
        
        for case let url as URL in enumerator {
            if url.hasDirectoryPath { continue }
            
            do {
                let attributes = try url.resourceValues(forKeys: [.fileSizeKey])
                if let size = attributes.fileSize {
                    totalSize += UInt64(size)
                }
            } catch {
                NSLog("Error getting file size: \(error)")
            }
        }
        
        return totalSize
    }
    
    func deleteOldScreenshots(olderThan date: Date) -> Int {
        var deletedCount = 0
        
        // First delete from database
        do {
            deletedCount = try DatabaseManager.shared.deleteOldScreenshots(olderThan: date)
            print("Deleted \(deletedCount) old screenshots")
        } catch {
            print("Error deleting old screenshots: \(error)")
        }
        
        // Then delete files
        // This is a simplified implementation that deletes entire date folders
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            NSLog("❌ Could not get application support directory")
            return deletedCount
        }
        let screenshotsFolder = appSupportURL.appendingPathComponent("AutoRecall/Screenshots")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: screenshotsFolder, includingPropertiesForKeys: nil)
            
            for url in contents {
                if url.hasDirectoryPath, let folderDate = dateFormatter.date(from: url.lastPathComponent), folderDate < date {
                    try fileManager.removeItem(at: url)
                }
            }
        } catch {
            NSLog("Error deleting old screenshots: \(error.localizedDescription)")
        }
        
        return deletedCount
    }
    
    // MARK: - Private Methods
    
    /// Helper method to check screen capture permission
    private func checkScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        // First check if permission was previously granted and stored
        if UserDefaults.standard.bool(forKey: "screenCapturePermissionGranted") {
            completion(true)
            return
        }
        
        // Otherwise check current permission status
        let hasPermission = CGDisplayStream(
            dispatchQueueDisplay: CGMainDisplayID(),
            outputWidth: 1,
            outputHeight: 1,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: nil,
            queue: DispatchQueue.global(),
            handler: { _, _, _, _ in }
        ) != nil
        
        // If permission is granted, store it
        if hasPermission {
            UserDefaults.standard.set(true, forKey: "screenCapturePermissionGranted")
        }
        
        completion(hasPermission)
    }
    
    /// Capture the current screen
    private func captureCurrentScreen() {
        NSLog("📸 Attempting to capture screen now")
        screenshotQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get current timestamp
            let timestamp = Date()
            
            // Capture all screens
            let screens = NSScreen.screens
            guard !screens.isEmpty else {
                NSLog("❌ No screens available")
                return
            }
            
            // For simplicity, we'll capture the main screen
            guard let mainScreen = NSScreen.main else { 
                NSLog("❌ No main screen detected")
            return
        }
        
            NSLog("📷 Capturing main screen with resolution: \(mainScreen.frame.width) x \(mainScreen.frame.height)")
            
            // Take the screenshot with error handling
            guard let cgImage = self.captureScreenImage(mainScreen) else {
                NSLog("❌ Failed to capture screenshot - permission issue or system error")
                
                // Notify user of failure if persistent
                DispatchQueue.main.async {
                    NotificationManager.shared.showNotification(
                        title: "Screenshot Failed",
                        body: "Unable to capture screenshot. Check screen recording permissions."
                    )
                }
            return
        }
        
            NSLog("✅ Successfully captured screen image with dimensions: \(cgImage.width) x \(cgImage.height)")
            
            // Convert to NSImage
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            // Skip if too similar to previous screenshot
            if self.isSimilarToLastScreenshot(nsImage) {
                NSLog("🔄 Screenshot skipped - too similar to previous")
                return
            }
            
            NSLog("💾 Saving new screenshot...")
            
            // Save the image
            self.saveScreenshot(image: nsImage)
            
            // Run analysis of the screenshot
            self.analyzeScreenshot(nsImage, timestamp: timestamp)
        }
    }
    
    /// Process image with OCR to extract text
    private func processImageWithOCR(_ cgImage: CGImage, timestamp: Date, screenIndex: Int) {
        // Process OCR on background queue
        ocrQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create a request handler
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Create a text recognition request
            let request = VNRecognizeTextRequest { (request, error) in
                // Handle error
                if let error = error {
                    NSLog("OCR error: \(error.localizedDescription)")
                    return
                }
                
                // Process results
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                
                // Extract text from observations
                var extractedText = ""
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    extractedText += topCandidate.string + "\n"
                }
                
                // Update screenshot record with OCR text
                DispatchQueue.main.async {
                    self.updateScreenshotWithOCRText(timestamp: timestamp, screenIndex: screenIndex, ocrText: extractedText)
                }
            }
            
            // Configure the request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Perform the request
            do {
                try requestHandler.perform([request])
            } catch {
                NSLog("Failed to perform OCR: \(error.localizedDescription)")
            }
        }
    }
    
    /// Update screenshot record with OCR text
    private func updateScreenshotWithOCRText(timestamp: Date, screenIndex: Int, ocrText: String) {
        // Find the screenshot record by timestamp and screen index
        let filename = "screen_\(screenIndex)_\(Int(timestamp.timeIntervalSince1970)).png"
        
        // Update the record with OCR text
        storage.updateOCRText(for: filename, text: ocrText)
        
        // Notify that new data is available
        NotificationCenter.default.post(name: Notification.Name("NewScreenshotData"), object: nil)
    }
    
    /// Get current application name
    private func getCurrentAppName() -> String {
        if let app = NSWorkspace.shared.frontmostApplication {
            return app.localizedName ?? "Unknown"
        }
        return "Unknown"
    }
    
    /// Get current window title
    private func getCurrentWindowTitle() -> String {
        // This is a simplified implementation
        // A more robust solution would use the Accessibility API
        if let app = NSWorkspace.shared.frontmostApplication {
            return "\(app.localizedName ?? "Unknown") Window"
        }
        return "Unknown Window"
    }
    
    /// Add the shouldSkipSimilarImage function implementation if it's missing
    private func shouldSkipSimilarImage(_ image: NSImage) -> Bool {
        if let imageHash = generateImageHash(image) {
            // Check similarity with previous image if available
            if let previousHash = lastScreenshotHash {
                let similarity = calculateHashSimilarity(previousHash, imageHash)
                
                // Update the hash for next time
                lastScreenshotHash = imageHash
                
                return similarity >= similarityThreshold
            }
            
            // First image, store the hash but don't skip
            lastScreenshotHash = imageHash
        }
        
        return false
    }
    
    // Add missing function for calculating image similarity
    private func calculateImageSimilarity(_ image1: NSImage, _ image2: NSImage) -> Double {
        // Simple implementation based on image hash comparison
        let hash1 = calculateImageHash(image1)
        let hash2 = calculateImageHash(image2)
        
        // Calculate Hamming distance between hashes
        let distance = hammingDistance(hash1, hash2)
        
        // Convert to similarity score (0.0 to 1.0)
        let maxDistance = Double(hash1.count)
        let similarity = 1.0 - (Double(distance) / maxDistance)
        
        return similarity
    }
    
    // Image hash calculation helper
    private func calculateImageHash(_ image: NSImage) -> [Bool] {
        // Resize image to 8x8 for comparison
        let size = NSSize(width: 8, height: 8)
        let resizedImage = NSImage(size: size)
        
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Convert to grayscale and create hash
        var hash = [Bool]()
        
        if let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 8, 
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) {
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 8, height: 8))
            
            if let data = context.data {
                let buffer = data.bindMemory(to: UInt8.self, capacity: 64)
                
                // Calculate average pixel value
                var sum: UInt32 = 0
                for i in 0..<64 {
                    sum += UInt32(buffer[i])
                }
                let average = UInt8(sum / 64)
                
                // Generate hash (1 if pixel value >= average, 0 otherwise)
                for i in 0..<64 {
                    hash.append(buffer[i] >= average)
                }
            }
        }
        
        return hash
    }
    
    // Hamming distance helper function
    private func hammingDistance(_ hash1: [Bool], _ hash2: [Bool]) -> Int {
        guard hash1.count == hash2.count else {
            return max(hash1.count, hash2.count) // Maximum distance if lengths don't match
        }
        
        var distance = 0
        for i in 0..<hash1.count {
            if hash1[i] != hash2[i] {
                distance += 1
            }
        }
        
        return distance
    }
    
    // Add missing getCurrentURL function
    private func getCurrentURL() -> String? {
        // Get the URL from the frontmost browser if possible
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName ?? ""
        
        if appName.contains("Safari") || appName.contains("Chrome") || appName.contains("Firefox") {
            // Try to get URL using AppleScript
            let script = """
            tell application "\(appName)"
                try
                    if name of current application is "Safari" then
                        return URL of current tab of front window
                    else
                        return URL of active tab of front window
                    end if
                on error
                    return ""
                end try
            end tell
            """
            
            if let url = runAppleScript(script), !url.isEmpty {
                return url
            }
        }
        
        return nil
    }
    
    // Helper method to run AppleScript
    private func runAppleScript(_ script: String) -> String? {
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let output = appleScript.executeAndReturnError(&error)
            
            if error == nil {
                return output.stringValue
            } else {
                NSLog("AppleScript error: \(String(describing: error))")
            }
        }
        
        return nil
    }
    
    // Add missing method to save screenshot record
    private func saveScreenshotRecord(path: String, appName: String, windowTitle: String, timestamp: Date, url: String?, isClipboardItem: Bool = false, isTranscription: Bool = false, ocrText: String = "", isVideo: Bool = false) {
        let screenshot = Screenshot(
            id: UUID(),
            path: path,
            timestamp: timestamp,
            appName: appName,
            windowTitle: windowTitle,
            url: url,
            isClipboardItem: isClipboardItem,
            isTranscription: isTranscription,
            ocrText: ocrText,
            isVideo: isVideo
        )
        
        storage.saveScreenshot(screenshot)
    }
    
    // Fix the clipboard image save method
    func saveClipboardItem() {
        // Check if pasteboard has changed before processing
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            NSLog("📋 Pasteboard hasn't changed, ignoring duplicate save request")
            return
        }
        
        lastChangeCount = currentChangeCount
        
        screenshotQueue.async {
            autoreleasepool {
                if let image = self.getClipboardImage() {
                    // Check for duplicate based on image hash
                    if let imageHash = self.generateImageHash(image) {
                        if imageHash == self.lastClipboardHash {
                            NSLog("📋 Duplicate clipboard image detected, skipping save")
                            return
                        }
                        self.lastClipboardHash = imageHash
                    }
                    
                    // Get current app and window info
                    let timestamp = Date()
                    let appName = self.getCurrentAppName()
                    let windowTitle = self.getCurrentWindowTitle()
                    let url = self.getCurrentURL()
                    
                    // Generate a unique filename
                    let filename = "\(Int(timestamp.timeIntervalSince1970))_\(UUID().uuidString).png"
                    
                    if let screenshotDir = self.storage.getScreenshotDirectory(for: timestamp) {
                        let path = screenshotDir.appendingPathComponent(filename).path
                        
                        // Ensure path is valid and not empty
                        guard !path.isEmpty else {
                            NSLog("❌ Cannot save clipboard image with empty path")
                            return
                        }
                        
                        var success = false
                        var savedPath = path
                        
                        // Try HEIC if available and enabled
                        if #available(macOS 10.13, *), UserDefaults.standard.bool(forKey: "useHEICFormatIfAvailable") {
                            let heicPath = path.replacingOccurrences(of: ".png", with: ".heic")
                            success = self.saveAsHEIC(image, path: heicPath)
                            
                            if success {
                                savedPath = heicPath
                            }
                        }
                        
                        // Fall back to PNG if HEIC failed or not available
                        if !success {
                            // Get compression level from user defaults
                            let compressionLevel = UserDefaults.standard.double(forKey: "imageCompressionLevel")
                            success = self.saveAsPNG(image, path: path, compressionLevel: compressionLevel)
                        }
                        
                        if success {
                            // Create a record
                            let screenshot = Screenshot(
                                id: UUID(),
                                path: savedPath,
                                timestamp: timestamp,
                                appName: appName,
                                windowTitle: windowTitle,
                                url: url,
                                isClipboardItem: true,
                                isTranscription: false,
                                ocrText: "",
                                isVideo: false
                            )
                            
                            // Save record to database
                            self.storage.saveScreenshot(screenshot)
                            
                            // Perform OCR on the image
                            self.performOCR(image) { ocrText in
                                if let text = ocrText {
                                    self.storage.updateOCRText(for: savedPath, text: text)
                                }
                            }
                            
                            // Enforce clipboard item limit
                            self.enforceClipboardItemLimit()
                            
                            NSLog("✅ Successfully saved clipboard image")
                        } else {
                            NSLog("❌ Failed to save clipboard image")
                        }
                    } else {
                        NSLog("❌ Could not get screenshot directory")
                    }
                } else {
                    NSLog("📋 No image found in clipboard")
                }
            }
        }
    }
    
    // Add a method to limit the number of clipboard items
    private func enforceClipboardItemLimit() {
        // Only keep the most recent clipboard items
        let maxItems = UserDefaults.standard.integer(forKey: "maxClipboardItems")
        if maxItems <= 0 {
            return // No limit if set to 0 or negative
        }
        
        self.dbQueue.async {
            do {
                // Get clipboard items without using try since it doesn't throw
                let clipboardItems = self.databaseManager.getClipboardItems(limit: 1000)
                if clipboardItems.count > maxItems {
                    // Calculate how many items to delete
                    let itemsToRemove = clipboardItems.count - maxItems
                    
                    // Get the oldest items to remove
                    let itemsToDelete = Array(clipboardItems.suffix(itemsToRemove))
                    
                    // Delete from database and filesystem
                    for item in itemsToDelete {
                        // Delete file
                        if FileManager.default.fileExists(atPath: item.path) {
                            try? FileManager.default.removeItem(atPath: item.path)
                        }
                        
                        // Delete from database without using try since we're ignoring the result
                        _ = self.databaseManager.deleteScreenshot(id: item.id.uuidString)
                    }
                    
                    NSLog("🧹 Cleaned up \(itemsToDelete.count) old clipboard items")
                }
            } 
            // NOTE: This is kept for future implementations that might throw errors
            // Adding a comment instead of a catch block to avoid the unreachable code warning
            // catch let error {
            //     NSLog("❌ Error enforcing clipboard limit: \(error.localizedDescription)")
            // }
        }
    }

    // Fix the transcription save method
    func saveTranscription() {
        // Check if pasteboard has changed before processing
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            NSLog("📋 Pasteboard hasn't changed, ignoring duplicate transcription request")
            return
        }
        
        lastChangeCount = currentChangeCount
        
        screenshotQueue.async {
            autoreleasepool {
                if let image = self.getClipboardImage() {
                    // Check for duplicate based on image hash
                    if let imageHash = self.generateImageHash(image) {
                        if imageHash == self.lastClipboardHash {
                            NSLog("📋 Duplicate clipboard image detected, skipping transcription save")
                            return
                        }
                        self.lastClipboardHash = imageHash
                    }
                    
                    // Get current app and window info
                    let timestamp = Date()
                    let appName = self.getCurrentAppName()
                    let windowTitle = self.getCurrentWindowTitle()
                    let url = self.getCurrentURL()
                    
                    // Generate a unique filename
                    let filename = "\(Int(timestamp.timeIntervalSince1970))_\(UUID().uuidString).png"
                    
                    if let screenshotDir = self.storage.getScreenshotDirectory(for: timestamp) {
                        let path = screenshotDir.appendingPathComponent(filename).path
                        
                        // Ensure path is valid and not empty
                        guard !path.isEmpty else {
                            NSLog("❌ Cannot save transcription image with empty path")
                            return
                        }
                        
                        var success = false
                        var savedPath = path
                        
                        // Try HEIC if available and enabled
                        if #available(macOS 10.13, *), UserDefaults.standard.bool(forKey: "useHEICFormatIfAvailable") {
                            let heicPath = path.replacingOccurrences(of: ".png", with: ".heic")
                            success = self.saveAsHEIC(image, path: heicPath)
                            
                            if success {
                                savedPath = heicPath
                            }
                        }
                        
                        // Fall back to PNG if HEIC failed or not available
                        if !success {
                            // Get compression level from user defaults
                            let compressionLevel = UserDefaults.standard.double(forKey: "imageCompressionLevel")
                            success = self.saveAsPNG(image, path: path, compressionLevel: compressionLevel)
                        }
                        
                        if success {
                            // Create a record
                            let screenshot = Screenshot(
                                id: UUID(),
                                path: savedPath,
                                timestamp: timestamp,
                                appName: appName,
                                windowTitle: windowTitle,
                                url: url,
                                isClipboardItem: true,
                                isTranscription: true,
                                ocrText: "",
                                isVideo: false
                            )
                            
                            // Save record to database
                            self.storage.saveScreenshot(screenshot)
                            
                            // Perform OCR on the image
                            self.performOCR(image) { ocrText in
                                if let text = ocrText {
                                    self.storage.updateOCRText(for: savedPath, text: text)
                                }
                            }
                            
                            // Enforce clipboard item limit
                            self.enforceClipboardItemLimit()
                            
                            NSLog("✅ Successfully saved transcription image")
                        } else {
                            NSLog("❌ Failed to save transcription image")
                        }
                    } else {
                        NSLog("❌ Could not get screenshot directory")
                    }
                } else {
                    NSLog("📋 No image found in clipboard for transcription")
                }
            }
        }
    }

    @objc func audioRecordingThumbnailReady(_ notification: Notification) {
        if let image = notification.userInfo?["image"] as? NSImage {
            // Save the thumbnail image to disk and database
            audioRecordingFinished(with: image)
        }
    }

    @objc func videoThumbnailReady(_ notification: Notification) {
        if let image = notification.userInfo?["image"] as? NSImage {
            // Save the thumbnail image to disk and database
            videoFinished(with: image)
        }
    }

    // Add these helper methods
    private func audioRecordingFinished(with image: NSImage) {
        // Create timestamp for this screenshot
        let timestamp = Date()
        
        // Generate a unique filename
        let filename = "\(Int(timestamp.timeIntervalSince1970))_\(UUID().uuidString).png"
        
        if let screenshotDir = self.storage.getScreenshotDirectory(for: timestamp) {
            let path = screenshotDir.appendingPathComponent(filename).path
            
            // Ensure path is valid and not empty
            guard !path.isEmpty else {
                NSLog("❌ Cannot save audio recording screenshot with empty path")
                return
            }
            
            // Get compression level from user defaults
            let compressionLevel = UserDefaults.standard.double(forKey: "imageCompressionLevel")
            let success = self.saveAsPNG(image, path: path, compressionLevel: compressionLevel)
            
            if success {
                // Save to database
                let screenshot = Screenshot(
                    id: UUID(),
                    path: path,
                    timestamp: timestamp,
                    appName: "AudioRecording",
                    windowTitle: "Audio Recording",
                    url: nil,
                    isClipboardItem: false,
                    isTranscription: true,
                    ocrText: "[Audio Recording]",
                    isVideo: false
                )
                
                storage.saveScreenshot(screenshot)
            }
        } else {
            NSLog("❌ Could not get screenshot directory for audio recording")
        }
    }

    private func videoFinished(with image: NSImage) {
        // Create timestamp for this screenshot
        let timestamp = Date()
        
        // Generate a unique filename
        let filename = "\(Int(timestamp.timeIntervalSince1970))_\(UUID().uuidString).png"
        
        if let screenshotDir = self.storage.getScreenshotDirectory(for: timestamp) {
            let path = screenshotDir.appendingPathComponent(filename).path
            
            // Ensure path is valid and not empty
            guard !path.isEmpty else {
                NSLog("❌ Cannot save video recording screenshot with empty path")
                return
            }
            
            // Get compression level from user defaults
            let compressionLevel = UserDefaults.standard.double(forKey: "imageCompressionLevel")
            let success = self.saveAsPNG(image, path: path, compressionLevel: compressionLevel)
            
            if success {
                // Save to database
                let screenshot = Screenshot(
                    id: UUID(),
                    path: path,
                    timestamp: timestamp,
                    appName: "VideoRecording",
                    windowTitle: "Screen Recording",
                    url: nil,
                    isClipboardItem: false,
                    isTranscription: false,
                    ocrText: "[Video Recording]",
                    isVideo: true
                )
                
                storage.saveScreenshot(screenshot)
                
                // Perform OCR on the image
                self.performOCR(image) { [weak self] ocrText in
                    if let text = ocrText, let self = self {
                        self.storage.updateOCRText(id: screenshot.id, ocrText: text)
                    }
                }
            }
        } else {
            NSLog("❌ Could not get screenshot directory for video recording")
        }
    }

    // Fix the getClipboardImage function to be more robust
    private func getClipboardImage() -> NSImage? {
        // Add error handling to prevent crashes when retrieving images
        let pasteboard = NSPasteboard.general
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.tiff.rawValue, NSPasteboard.PasteboardType.png.rawValue]) {
            if let image = NSImage(pasteboard: pasteboard) {
                return image
            }
        }
        return nil
    }
    
    private func createScreenshot(id: UUID = UUID(), path: String, appName: String, windowTitle: String, timestamp: Date, url: String?, isClipboardItem: Bool = false, isTranscription: Bool = false, ocrText: String = "", isVideo: Bool = false) -> Screenshot {
        Screenshot(
            id: id,
            path: path,
            timestamp: timestamp,
            appName: appName,
            windowTitle: windowTitle,
            url: url,
            isClipboardItem: isClipboardItem,
            isTranscription: isTranscription,
            ocrText: ocrText,
            isVideo: isVideo
        )
    }
    
    // MARK: - Public Capture Methods
    
    /// Captures a single screenshot immediately
    func captureSingleScreenshot() {
        NSLog("📸 Manual screenshot capture requested")
        captureCurrentScreen()
    }
}

// MARK: - Extensions

extension NSImage {
    /// Convert NSImage to JPEG data with specified compression factor
    func jpegRepresentation(compressionFactor: CGFloat = 0.8) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Float(compressionFactor))])
    }
    
    /// Convert NSImage to PNG data
    func pngRepresentation() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}

extension Data {
    var md5String: String {
        withUnsafeBytes { bytes in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(self.count), &hash)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
    }
}

// MARK: - Screenshot Record Model

struct ScreenshotRecord: Identifiable, Codable {
    let id: String
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
}

// Extension to add ClipboardItemType support
extension ScreenshotRecord {
    var type: ClipboardItemType {
        // Check if it's a URL
        if let url = self.url, !url.isEmpty, URL(string: url) != nil {
            return .url
        }
        
        // Check based on window title or ocrText content
        if windowTitle.contains("URL") {
            return .url
        } else if windowTitle.contains("Image") {
            return .text // We'll treat images as text for display purposes
        } else if ocrText.contains("@") && ocrText.contains(".") {
            return .email
        } else if ocrText.matches(pattern: "\\d{3}[-.\\s]?\\d{3}[-.\\s]?\\d{4}") {
            return .phone
        } else if ocrText.matches(pattern: "\\d{4}[-.\\s]?\\d{4}[-.\\s]?\\d{4}[-.\\s]?\\d{4}") {
            return .sensitiveData
        } else {
            return .text
        }
    }
}

// Helper for regex pattern matching
extension String {
    func matches(pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: self.utf16.count)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension ScreenshotManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        NSLog("Audio recording finished. Success: \(flag)")
        
        if !flag {
            // Handle unsuccessful recording
            NSLog("Audio recording was unsuccessful")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            NSLog("Audio recording error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Public Methods

/// Check if screen capture permission is granted
func checkScreenCapturePermission(completion: @escaping (Bool) -> Void) {
    // First check if permission was previously granted and stored
    if UserDefaults.standard.bool(forKey: "screenCapturePermissionGranted") {
        completion(true)
        return
    }
    
    // Otherwise check current permission status
    let hasPermission = CGDisplayStream(
        dispatchQueueDisplay: CGMainDisplayID(),
        outputWidth: 1,
        outputHeight: 1,
        pixelFormat: Int32(kCVPixelFormatType_32BGRA),
        properties: nil,
        queue: DispatchQueue.global(),
        handler: { _, _, _, _ in }
    ) != nil
    
    // If permission is granted, store it
    if hasPermission {
        UserDefaults.standard.set(true, forKey: "screenCapturePermissionGranted")
    }
    
    completion(hasPermission)
}

extension ScreenshotManager: AVAssetWriterDelegate {
    func assetWriter(_ writer: AVAssetWriter, didFinishWritingWithError error: Error?) {
        if let error = error {
            NSLog("❌ Error writing video: \(error.localizedDescription)")
            return
        }
        
        _ = writer.outputURL
        // Log success
        NSLog("✅ Video recorded successfully to \(writer.outputURL.path)")
    }
} 