import SwiftUI
import AppKit

struct ScreenshotThumbnail: View {
    let screenshot: ScreenshotRecord
    @State private var image: NSImage?
    @State private var isLoading: Bool = true
    @State private var loadError: Bool = false
    
    var body: some View {
        VStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 90)
                    .cornerRadius(5)
            } else if loadError {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 160, height: 90)
                        .cornerRadius(5)
                    
                    if screenshot.path.hasSuffix(".txt") {
                        Image(systemName: "doc.text")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 90)
                    .cornerRadius(5)
                    .overlay(ProgressView())
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Skip loading for text files
        if screenshot.path.hasSuffix(".txt") {
            isLoading = false
            loadError = true
            return
        }
        
        let fileURL = URL(fileURLWithPath: screenshot.path)
        let targetSize = CGSize(width: 160, height: 90)
        
        ImageLoader.shared.loadImage(from: fileURL, targetSize: targetSize) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let loadedImage):
                    self.image = loadedImage
                case .failure:
                    self.loadError = true
                }
            }
        }
    }
} 