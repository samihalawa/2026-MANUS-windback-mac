import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isSeeking = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
            
            // Controls
            HStack {
                // Play/Pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                // Current time
                Text(formatTime(currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                
                // Progress slider
                Slider(
                    value: $currentTime,
                    in: 0...max(0.1, duration),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            seekToTime(currentTime)
                        }
                    }
                )
                .accentColor(.blue)
                
                // Duration
                Text(formatTime(duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                
                // Restart button
                Button(action: restartVideo) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 36)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(8)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updatePlayerTime()
        }
    }
    
    private func setupPlayer() {
        let player = AVPlayer(url: videoURL)
        self.player = player
        
        // Get duration
        updateDuration()
    }
    
    private func updateDuration() {
        guard let player = player else { return }
        
        if #available(macOS 13.0, *) {
            Task {
                do {
                    let asset = player.currentItem?.asset
                    if let asset = asset as? AVURLAsset {
                        let durationValue = try await asset.load(.duration).seconds
                        DispatchQueue.main.async {
                            self.duration = durationValue
                        }
                    }
                } catch {
                    print("Error loading duration: \(error)")
                }
            }
        } else {
            // Legacy approach for older macOS versions
            var error: NSError?
            player.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                DispatchQueue.main.async {
                    let status = player.currentItem?.asset.statusOfValue(forKey: "duration", error: &error)
                    if status == .loaded {
                        let durationValue = player.currentItem?.asset.duration.seconds ?? 0
                        self.duration = durationValue
                    }
                }
            }
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        isPlaying.toggle()
        
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
    
    private func updatePlayerTime() {
        guard let player = player, !isSeeking else { return }
        
        currentTime = player.currentTime().seconds
        
        // Check if video ended
        if currentTime >= duration {
            isPlaying = false
        }
    }
    
    private func seekToTime(_ time: Double) {
        guard let player = player else { return }
        
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if completed {
                if self.isPlaying {
                    player.play()
                }
            }
        }
    }
    
    private func restartVideo() {
        seekToTime(0)
        
        if !isPlaying {
            isPlaying = true
            player?.play()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Use a placeholder instead of a sample video URL
        VStack {
            Text("Video Player Preview")
                .font(.headline)
            Text("Video playback available at runtime")
                .font(.subheadline)
        }
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.2))
        .previewLayout(.sizeThatFits)
    }
} 