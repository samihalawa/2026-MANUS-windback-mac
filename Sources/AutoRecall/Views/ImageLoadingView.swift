import SwiftUI
import AppKit

struct ImageLoadingView: View {
    let url: URL
    let targetSize: CGSize
    @State private var image: NSImage?
    @State private var loadError: Bool = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
            } else if loadError {
                // Show placeholder for non-image files or loading errors
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: targetSize.width, height: targetSize.height)
                    
                    if url.pathExtension.lowercased() == "txt" {
                        VStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("Text File")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("Image Failed to Load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // Loading state
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: targetSize.width, height: targetSize.height)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Skip loading attempt for text files
        if url.pathExtension.lowercased() == "txt" {
            loadError = true
            return
        }
        
        NSLog("Loading image from: \(url.path)")
        ImageLoader.shared.loadImage(from: url, targetSize: targetSize) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedImage):
                    self.image = loadedImage
                case .failure(let error):
                    NSLog("⚠️ Failed to load image from: \(url.path): \(error.localizedDescription)")
                    self.loadError = true
                }
            }
        }
    }
} 