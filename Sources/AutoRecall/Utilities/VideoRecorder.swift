import Foundation
import AVFoundation
import ScreenCaptureKit
import AppKit

// MARK: - Stream Output Delegate
class StreamOutput: NSObject, SCStreamOutput {
    weak var videoRecorder: VideoRecorder?
    
    init(videoRecorder: VideoRecorder?) {
        self.videoRecorder = videoRecorder
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        videoRecorder?.processFrame(sampleBuffer)
    }
}

// MARK: - Video Recorder
class VideoRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = VideoRecorder()
    
    // Recording state
    public var isRecording = false
    private var recordingStartTime: Date?
    private var videoURL: URL?
    
    // Screen capture
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    
    // Video writing
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor?
    
    // Storage
    private let storage = StorageManager.shared
    private var videoCount = 0
    
    // Settings
    private var videoWidth: Int = 1920
    private var videoHeight: Int = 1080
    private var frameRate: Int = 30
    
    // Compression settings
    private var compressionQuality: CompressionQuality = .medium
    
    enum CompressionQuality: String, CaseIterable {
        case ultraHigh = "Ultra High Compression"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var bitRate: Int {
            switch self {
            case .ultraHigh: return 8_000_000   // 8 Mbps for highest quality
            case .high: return 5_000_000   // 5 Mbps
            case .medium: return 2_500_000 // 2.5 Mbps
            case .low: return 1_000_000    // 1 Mbps
            }
        }
        
        var profileLevel: String {
            switch self {
            case .ultraHigh: return AVVideoProfileLevelH264HighAutoLevel
            case .high: return AVVideoProfileLevelH264HighAutoLevel
            case .medium: return AVVideoProfileLevelH264HighAutoLevel
            case .low: return AVVideoProfileLevelH264MainAutoLevel
            }
        }
    }
    
    // Set compression quality and immediately apply settings
    func setCompressionQuality(_ quality: CompressionQuality) {
        compressionQuality = quality
        NSLog("Video compression quality set to: \(quality.rawValue) (\(quality.bitRate / 1_000_000) Mbps)")
        
        // If we're currently recording, we can't change the compression settings
        // mid-stream, so we'll just log that it will apply to the next recording
        if isRecording {
            NSLog("Compression settings will apply to the next recording")
        }
    }
    
    private override init() {
        // Initialize with default settings
        // Read saved compression quality from UserDefaults
        if let savedQuality = UserDefaults.standard.string(forKey: "videoCompressionQuality"),
           let quality = CompressionQuality(rawValue: savedQuality) {
            compressionQuality = quality
        }
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        guard !isRecording else { return }
        
        NSLog("Starting video recording")
        isRecording = true
        recordingStartTime = Date()
        
        // Check screen recording permission
        checkScreenCapturePermission { hasPermission in
            guard hasPermission else {
                NSLog("Screen recording permission not granted")
                self.isRecording = false
                return
            }
            
            // Set up video storage
            self.setupVideoStorage()
            
            // Set up video capture
            self.setupVideoCapture()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        NSLog("Stopping video recording")
        isRecording = false
        
        // Stop capture
        stopVideoCapture()
        
        // Notify recording complete
        NotificationCenter.default.post(
            name: NSNotification.Name("VideoRecordingComplete"),
            object: videoURL
        )
    }
    
    // MARK: - Private Methods
    
    private func setupVideoStorage() {
        // Create a unique filename for the video
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "recording_\(dateString)_\(videoCount).mp4"
        videoCount += 1
        
        // Get videos directory
        let videosDir = storage.getVideosDirectory()
        
        // Create full path
        videoURL = videosDir?.appendingPathComponent(filename)
        
        NSLog("Video will be saved to: \(videoURL?.path ?? "unknown")")
    }
    
    private func setupVideoCapture() {
        let captureTask = Task<Void, Never> {
            do {
                // Get available screen content
                let content = try await SCShareableContent.current
                
                guard let mainDisplay = content.displays.first else {
                    NSLog("No displays available for capture")
                    self.isRecording = false
                    return
                }
                
                // Configure screen capture
                let configuration = SCStreamConfiguration()
                configuration.width = self.videoWidth
                configuration.height = self.videoHeight
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(self.frameRate))
                configuration.queueDepth = 5
                
                // Create filter for the display
                let filter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])
                
                // Create stream output handler
                let output = StreamOutput(videoRecorder: self)
                self.streamOutput = output
                
                do {
                    // Create stream without try since it doesn't throw errors
                    let captureStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
                    self.stream = captureStream
                    
                    // Add stream output
                    try captureStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
                    
                    // Start capture
                    try await captureStream.startCapture()
                    
                    // Initialize video writing
                    self.initializeVideoWriter()
                } catch {
                    NSLog("Error creating or starting stream: \(error)")
                    self.isRecording = false
                }
            } catch {
                NSLog("Error getting screen content: \(error)")
                self.isRecording = false
            }
        }
        
        // Keep the Task reference if needed
        _ = captureTask
    }
    
    private func initializeVideoWriter() {
        guard let videoURL = videoURL else {
            NSLog("Video URL not set")
            return
        }
        
        do {
            // Create asset writer
            assetWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
            
            // Configure video settings with enhanced compression
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoWidth,
                AVVideoHeightKey: videoHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: compressionQuality.bitRate,
                    AVVideoProfileLevelKey: compressionQuality.profileLevel,
                    AVVideoMaxKeyFrameIntervalKey: frameRate * 2, // Keyframe every 2 seconds
                    AVVideoAllowFrameReorderingKey: true,
                    AVVideoExpectedSourceFrameRateKey: frameRate,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                    AVVideoQualityKey: 0.8, // Balance between quality and size
                    AVVideoMaxKeyFrameIntervalDurationKey: 2.0, // Maximum 2 seconds between keyframes
                    AVVideoAverageNonDroppableFrameRateKey: frameRate / 2 // For smoother motion
                ]
            ]
            
            // Create writer input
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            // Create pixel buffer adapter
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: videoWidth,
                kCVPixelBufferHeightKey as String: videoHeight
            ]
            
            assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: assetWriterInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            // Add input to writer
            if assetWriter?.canAdd(assetWriterInput!) == true {
                assetWriter?.add(assetWriterInput!)
                
                // Start writing session
                assetWriter?.startWriting()
                assetWriter?.startSession(atSourceTime: CMTime.zero)
                
                NSLog("Video writer initialized with compression quality: \(compressionQuality.rawValue)")
            } else {
                NSLog("Cannot add asset writer input to asset writer")
            }
        } catch {
            NSLog("Error creating asset writer: \(error)")
        }
    }
    
    private func stopVideoCapture() {
        // Stop stream capture
        Task {
            do {
                try await stream?.stopCapture()
                stream = nil
            } catch {
                NSLog("Error stopping stream capture: \(error)")
            }
        }
        
        // Finalize video writing
        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting {
            NSLog("Video writing finished")
            self.assetWriter = nil
            self.assetWriterInput = nil
            self.assetWriterPixelBufferInput = nil
        }
    }
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let assetWriterInput = assetWriterInput,
              let assetWriterPixelBufferInput = assetWriterPixelBufferInput,
              assetWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        // Get the pixel buffer from the sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            NSLog("Could not get pixel buffer from sample buffer")
            return
        }
        
        // Get the presentation time
        var presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if recordingStartTime == nil {
            recordingStartTime = Date()
        }
        
        // Adjust the presentation time to be relative to the start time
        presentationTime = CMTimeMakeWithSeconds(
            presentationTime.seconds - (recordingStartTime?.timeIntervalSinceNow ?? 0),
            preferredTimescale: presentationTime.timescale
        )
        
        // Write the pixel buffer
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: presentationTime)
    }
    
    private func checkScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        let hasPermission = CGPreflightScreenCaptureAccess()
        
        if hasPermission {
            completion(true)
        } else {
            // Request permission
            CGRequestScreenCaptureAccess()
            
            // Check again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let hasPermissionNow = CGPreflightScreenCaptureAccess()
                completion(hasPermissionNow)
            }
        }
    }
} 