import SwiftUI
import AVFoundation
import UserNotifications

struct VideosView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    
    var body: some View {
        VStack {
            Text("Videos View")
                .font(.largeTitle)
                .padding()
            
            Text("This is where captured video recordings will appear.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private var recordingUI: some View {
        VStack(spacing: 20) {
            Image(systemName: "record.circle")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .opacity(0.8)
                .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
            
            Text("Recording in progress...")
                .font(.title2)
            
            Text("Duration: \(formattedDuration)")
                .font(.headline)
                .monospacedDigit()
            
            Button("Stop Recording") {
                stopRecording()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.top, 20)
        }
        .padding()
    }
    
    private var instructionsUI: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Record Your Screen")
                .font(.title2)
            
            Text("Capture video recordings of your screen activity.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Start Recording") {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)
        }
        .padding()
    }
    
    private var formattedDuration: String {
        // In a real implementation, would track the actual duration
        // For now, return a placeholder
        return "00:00"
    }
    
    private func toggleVideoRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Request screen recording permission if needed
        appState.startVideoRecording()
        
        // Update local state
        isRecording = true
        
        // Show notification
        showNotification(title: "Video Recording Started", body: "Your screen is now being recorded")
    }
    
    private func stopRecording() {
        // Stop recording
        appState.stopVideoRecording()
        
        // Update local state
        isRecording = false
        
        // Show notification
        showNotification(title: "Video Recording Stopped", body: "Your screen recording has been saved")
        
        // Update storage usage
        updateStorageUsage()
    }
    
    private func updateStorageUsage() {
        // In a real implementation, would update storage usage statistics
    }
    
    private func showNotification(title: String, body: String) {
        NotificationManager.shared.showNotification(title: title, body: body, identifier: nil)
    }
}

struct VideosView_Previews: PreviewProvider {
    static var previews: some View {
        VideosView()
            .environmentObject(AppState.shared)
    }
} 