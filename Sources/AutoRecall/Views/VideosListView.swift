import SwiftUI
import AVKit
import UserNotifications

struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
    var duration: TimeInterval
    var creationDate: Date
    var thumbnail: NSImage?

    static func from(url: URL) async -> VideoItem {
        let asset = AVURLAsset(url: url)
        
        // Use new async/await API to load duration
        var duration: TimeInterval = 0
        if #available(macOS 13.0, *) {
            do {
                duration = try await asset.load(.duration).seconds
            } catch {
                print("Error loading duration: \(error)")
            }
        } else {
            // Fallback for older versions
            duration = asset.duration.seconds
        }
        
        let fileManager = FileManager.default
        let creationDate: Date
        let thumbnail: NSImage?
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            creationDate = attributes[.creationDate] as? Date ?? Date.distantPast
        } catch {
            print("Error getting file attributes: \(error)")
            creationDate = Date.distantPast
        }
        
        // Generate thumbnail
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
            thumbnail = NSImage(cgImage: imageRef, size: NSSize(width: imageRef.width, height: imageRef.height))
        } catch {
            print("Could not generate thumbnail: \(error)")
            thumbnail = nil
        }
        
        return VideoItem(
            url: url,
            duration: duration,
            creationDate: creationDate,
            thumbnail: thumbnail
        )
    }
}

enum SortOption: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case longest = "Longest First"
    case shortest = "Shortest First"
}

struct VideosListView: View {
    @ObservedObject var appState: AppState = AppState.shared
    @State private var videos: [VideoItem] = []
    @State private var selectedVideo: VideoItem? = nil
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var videoToDelete: VideoItem?
    @State private var showDeleteAllConfirmation = false
    @State private var sortOption: SortOption = .newest
    @State private var retentionDays: Int = 30
    @State private var showSettings = false

    var body: some View {
        VStack {
            HStack {
                Text("Videos")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: sortOption) { _ in
                    sortVideos()
                }
                
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gear")
                }
                .popover(isPresented: $showSettings) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Video Settings")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Stepper("Retention days: \(retentionDays)", value: $retentionDays, in: 1...365)
                            .onChange(of: retentionDays) { _ in
                                saveSettings()
                            }
                        
                        Button("Apply Cleanup") {
                            cleanupOldVideos()
                        }
                        .padding(.top, 5)
                    }
                    .frame(width: 250)
                    .padding()
                }
                
                Button(action: {
                    showDeleteAllConfirmation = true
                }) {
                    Image(systemName: "trash")
                }
                .alert(isPresented: $showDeleteAllConfirmation) {
                    Alert(
                        title: Text("Delete All Videos"),
                        message: Text("Are you sure you want to delete all videos? This cannot be undone."),
                        primaryButton: .destructive(Text("Delete All")) {
                            deleteAllVideos()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                Button(action: {
                    loadVideos()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if videos.isEmpty {
                Spacer()
                Text("No videos available")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))], spacing: 16) {
                        ForEach(videos) { video in
                            VideoItemView(video: video, onDelete: {
                                videoToDelete = video
                                showingDeleteAlert = true
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Video"),
                message: Text("Are you sure you want to delete this video? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let video = videoToDelete {
                        deleteVideo(video)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            retentionDays = UserDefaults.standard.integer(forKey: "videoRetentionDays")
            if retentionDays == 0 {
                retentionDays = 30
                UserDefaults.standard.set(retentionDays, forKey: "videoRetentionDays")
            }
            loadVideos()
        }
    }
    
    private func loadVideos() {
        isLoading = true
        videos = []
        
        DispatchQueue.global().async {
            // Get videos directory from StorageManager
            if let videosDirectory = StorageManager.shared.getVideosDirectory() {
                let fileManager = FileManager.default
                
                do {
                    let videoURLs = try fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
                        .filter { $0.pathExtension.lowercased() == "mp4" }
                    
                    var videoItems: [VideoItem] = []
                    
                    for url in videoURLs {
                        let asset = AVURLAsset(url: url)
                        var durationSeconds: Double = 0
                        
                        if #available(macOS 13.0, *) {
                            // We need to use a synchronous approach here since we're in a loop
                            let semaphore = DispatchSemaphore(value: 0)
                            Task {
                                do {
                                    durationSeconds = try await asset.load(.duration).seconds
                                    semaphore.signal()
                                } catch {
                                    print("Error loading duration: \(error)")
                                    semaphore.signal()
                                }
                            }
                            // Wait for the async task to complete
                            _ = semaphore.wait(timeout: .now() + 0.5)
                        } else {
                            // Fallback for older versions
                            durationSeconds = CMTimeGetSeconds(asset.duration)
                        }
                        
                        // Get creation date
                        let attributes = try fileManager.attributesOfItem(atPath: url.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date.distantPast
                        
                        // Generate thumbnail
                        let thumbnail = generateThumbnail(for: url)
                        
                        let videoItem = VideoItem(
                            url: url,
                            duration: durationSeconds,
                            creationDate: creationDate,
                            thumbnail: thumbnail
                        )
                        
                        videoItems.append(videoItem)
                    }
                    
                    DispatchQueue.main.async {
                        self.videos = videoItems
                        self.sortVideos()
                        self.isLoading = false
                    }
                } catch {
                    print("Error loading videos: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func deleteVideo(_ video: VideoItem) {
        DispatchQueue.global().async {
            do {
                try FileManager.default.removeItem(at: video.url)
                
                // Notify user
                let content = UNMutableNotificationContent()
                content.title = "Video Deleted"
                content.body = "The video has been successfully deleted"
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString, 
                    content: content, 
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                
                UNUserNotificationCenter.current().add(request)
                
                DispatchQueue.main.async {
                    // Remove from the list
                    self.videos.removeAll { $0.id == video.id }
                    
                    // Update storage usage
                    self.updateStorageUsage()
                }
            } catch {
                print("Error deleting video: \(error)")
            }
        }
    }
    
    private func deleteAllVideos() {
        DispatchQueue.global().async {
            if let videosDirectory = StorageManager.shared.getVideosDirectory() {
                let fileManager = FileManager.default
                
                do {
                    let videoURLs = try fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                        .filter { $0.pathExtension.lowercased() == "mp4" }
                    
                    for url in videoURLs {
                        try fileManager.removeItem(at: url)
                    }
                    
                    // Notify user
                    let content = UNMutableNotificationContent()
                    content.title = "All Videos Deleted"
                    content.body = "All videos have been successfully deleted"
                    
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString, 
                        content: content, 
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    )
                    
                    UNUserNotificationCenter.current().add(request)
                    
                    DispatchQueue.main.async {
                        self.videos = []
                        self.updateStorageUsage()
                    }
                } catch {
                    print("Error deleting all videos: \(error)")
                }
            }
        }
    }
    
    private func cleanupOldVideos() {
        DispatchQueue.global().async {
            let calendar = Calendar.current
            if let date = calendar.date(byAdding: .day, value: -self.retentionDays, to: Date()) {
                StorageManager.shared.deleteOldVideos(olderThan: date)
                
                DispatchQueue.main.async {
                    self.loadVideos()
                    self.updateStorageUsage()
                }
            }
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(retentionDays, forKey: "videoRetentionDays")
    }
    
    private func updateStorageUsage() {
        let storageSize = StorageManager.shared.calculateVideosStorageSize()
        print("Current video storage size: \(formatSize(bytes: storageSize))")
    }
    
    private func formatSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func sortVideos() {
        switch sortOption {
        case .newest:
            videos.sort { $0.creationDate > $1.creationDate }
        case .oldest:
            videos.sort { $0.creationDate < $1.creationDate }
        case .longest:
            videos.sort { $0.duration > $1.duration }
        case .shortest:
            videos.sort { $0.duration < $1.duration }
        }
    }
    
    private func generateThumbnail(for videoURL: URL) -> NSImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get thumbnail at 1 second
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("Could not generate thumbnail: \(error)")
            return nil
        }
    }
}

struct VideoItemView: View {
    let video: VideoItem
    let onDelete: () -> Void
    @State private var isPlaying = false
    
    var body: some View {
        VStack {
            if let thumbnail = video.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Button(action: {
                            isPlaying = true
                        }) {
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "video.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(formattedDate(video.creationDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text(formattedDuration(video.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $isPlaying) {
            VideoPlayerWrapper(url: video.url)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoPlayerWrapper: View {
    let url: URL
    
    var body: some View {
        VStack {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(minHeight: 400)
            
            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 450)
    }
}

struct VideosListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VideosListView()
                .environmentObject(AppState.shared)
        }
    }
}

private func getDuration(for url: URL) -> String {
    if #available(macOS 13.0, *) {
        // Using modern API
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let durationSeconds = try await asset.load(.duration).seconds
                return formatDuration(seconds: durationSeconds)
            } catch {
                print("Error loading duration: \(error)")
                return "0:00"
            }
        }
        return "0:00" // Default return while Task completes
    } else {
        // Legacy approach
        let asset = AVAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        return formatDuration(seconds: durationSeconds)
    }
}

private func formatDuration(seconds: Double) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
}

func fetchVideoDuration(url: URL) async -> String {
    let asset = AVURLAsset(url: url)
    var durationSeconds: Double = 0
    
    if #available(macOS 13.0, *) {
        do {
            durationSeconds = try await asset.load(.duration).seconds
        } catch {
            print("Error loading duration: \(error)")
        }
    } else {
        // Fallback for older versions
        durationSeconds = CMTimeGetSeconds(asset.duration)
    }
    
    // Format the duration
    let minutes = Int(durationSeconds) / 60
    let seconds = Int(durationSeconds) % 60
    return String(format: "%d:%02d", minutes, seconds)
} 