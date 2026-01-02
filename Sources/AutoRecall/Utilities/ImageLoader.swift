// New file for image management
import Foundation
import AppKit

enum ImageLoaderError: Error {
    case fileNotFound
    case invalidImageData
    case imageCreationFailed
    case unsupportedFileType
}

class ImageLoader {
    static let shared = ImageLoader()
    
    private let imageCache = NSCache<NSString, NSImage>()
    
    private init() {
        // Set up cache limits
        imageCache.countLimit = 100
    }
    
    func loadImage(from url: URL, targetSize: CGSize, completion: @escaping (Result<NSImage, Error>) -> Void) {
        let key = url.path as NSString
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: key) {
            completion(.success(cachedImage))
            return
        }
        
        // Skip text files
        if url.pathExtension.lowercased() == "txt" {
            completion(.failure(ImageLoaderError.unsupportedFileType))
            return
        }
        
        // File operations are performed in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if file exists
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: url.path) else {
                    throw ImageLoaderError.fileNotFound
                }
                
                // Load image data
                let imageData = try Data(contentsOf: url)
                
                // Create image from data
                guard let nsImage = NSImage(data: imageData) else {
                    throw ImageLoaderError.imageCreationFailed
                }
                
                // Resize if needed
                let resizedImage = self.resizeImage(nsImage, to: targetSize)
                
                // Cache the image
                self.imageCache.setObject(resizedImage, forKey: key)
                
                // Return the result
                DispatchQueue.main.async {
                    completion(.success(resizedImage))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        // If the image is already smaller than target size, return original
        if image.size.width <= size.width && image.size.height <= size.height {
            return image
        }
        
        // Create resized image
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), 
                  operation: .copy, fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        return newImage
    }
    
    func precomposited() -> NSImage {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return self
        }
        return NSImage(data: pngData) ?? self
    }
} 