import Foundation
import ScreenCaptureKit
import CoreGraphics
import Combine

/// A capture engine that wraps SCStream and provides frame capture functionality
class SCStreamCaptureEngine: NSObject, SCStreamOutput {
    // Callback when a new frame is captured
    var onFrame: ((CGImage) -> Void)?
    
    // Stream and configuration
    private var stream: SCStream
    private var configuration: SCStreamConfiguration
    
    // Frame rate management
    private var lastFrameTime: CFTimeInterval = 0
    private var targetFrameInterval: CFTimeInterval = 1.0 / 30.0  // Default to 30 FPS
    
    // Error handling
    private var errorHandler: ((Error) -> Void)?
    
    // Frame processing queue
    private let processingQueue = DispatchQueue(label: "com.autorecall.frameProcessingQueue", qos: .userInteractive)
    
    /// Initialize with an SCStream
    init(stream: SCStream, configuration: SCStreamConfiguration, targetFPS: Double = 30.0) {
        self.stream = stream
        self.configuration = configuration
        self.targetFrameInterval = 1.0 / targetFPS
        super.init()
    }
    
    /// Set a handler for errors
    func setErrorHandler(_ handler: @escaping (Error) -> Void) {
        self.errorHandler = handler
    }
    
    /// Set the target frame rate
    func setTargetFrameRate(_ fps: Double) {
        self.targetFrameInterval = 1.0 / fps
        
        // Update the stream configuration if possible
        let updatedConfig = self.configuration
        updatedConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        
        self.stream.updateConfiguration(updatedConfig)
        self.configuration = updatedConfig
    }
    
    // MARK: - SCStreamOutput Protocol
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Only process video frames
        guard type == .screen else { return }
        
        // Check if this frame should be processed based on target FPS
        let currentTime = CACurrentMediaTime()
        guard (currentTime - lastFrameTime) >= targetFrameInterval else { return }
        
        // Update last frame time
        lastFrameTime = currentTime
        
        // Process frame on background queue
        processingQueue.async { [weak self] in
            guard let self = self,
                  // Get the pixel buffer from the sample buffer
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                  // Create a CG image from the pixel buffer
                  let cgImage = self.createCGImage(from: pixelBuffer) else {
                return
            }
            
            // Deliver the frame via callback
            self.onFrame?(cgImage)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a CGImage from a CVPixelBuffer
    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    /// Stop capturing frames
    func stopCapture() {
        // Clear the callback to avoid memory leaks
        onFrame = nil
    }
} 