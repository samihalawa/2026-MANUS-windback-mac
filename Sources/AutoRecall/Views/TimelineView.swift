import SwiftUI

struct TimelineView: View {
    @ObservedObject var appState: AppState = AppState.shared
    @State private var isLoading = true
    @State private var selectedDay = Date()
    @State private var screenshotsForSelectedDay: [Screenshot] = []
    @State private var selectedScreenshotToDelete: Screenshot?
    @State private var showingDeleteAlert = false
    @State private var isRecording = false
    
    var body: some View {
        VStack {
            // Header
            HStack {
                // Date selector
                DatePicker(
                    "",
                    selection: $selectedDay,
                    displayedComponents: .date
                )
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .onChange(of: selectedDay) { _ in
                    loadScreenshots()
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 12) {
                    Button(action: {
                        captureScreenshot()
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Take Screenshot")
                    
                    Button(action: {
                        DispatchQueue.main.async {
                            selectedDay = Date()
                        }
                    }) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Go to Today")
                }
            }
            .padding()
            
            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading screenshots...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else if screenshotsForSelectedDay.isEmpty {
                Spacer()
                Image(systemName: "photo")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                Text("No Screenshots Found")
                    .font(.title)
                    .padding()
                Text("Screenshots taken on this day will appear here")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(screenshotsForSelectedDay, id: \.id) { screenshot in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(formatDate(screenshot.timestamp))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        selectedScreenshotToDelete = screenshot
                                        showingDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                if screenshot.isVideo {
                                    Text("Video Recording")
                                        .font(.headline)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    VStack {
                                        if FileManager.default.fileExists(atPath: screenshot.path) {
                                            ImageLoadingView(
                                                url: URL(fileURLWithPath: screenshot.path),
                                                targetSize: CGSize(width: 800, height: 400)
                                            )
                                            .frame(maxWidth: .infinity)
                                            .cornerRadius(8)
                                        } else {
                                            // Show error for missing file
                                            VStack(spacing: 10) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 36))
                                                    .foregroundColor(.orange)
                                                Text("Image file not found")
                                                    .font(.headline)
                                                Text(screenshot.path)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }
                                            .frame(height: 200)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                
                                if !screenshot.ocrText.isEmpty {
                                    DisclosureGroup("OCR Text") {
                                        Text(screenshot.ocrText)
                                            .font(.body)
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.windowBackgroundColor))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadScreenshots()
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if isRecording {
                        stopCapturingScreenshot()
                    } else {
                        startCapturingScreenshot()
                    }
                }) {
                    Label(isRecording ? "Stop" : "Start", systemImage: isRecording ? "stop.circle" : "record.circle")
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Screenshot"),
                message: Text("Are you sure you want to delete this screenshot? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let screenshot = selectedScreenshotToDelete {
                        deleteScreenshot(screenshot)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    func captureScreenshot() {
        // Use only public methods to trigger screenshots
        let manager = ScreenshotManager.shared
        
        // Start capturing and stop after a delay to capture one screenshot
        manager.startCapturing()
        
        // Wait a brief moment then stop capturing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            manager.stopCapturing()
            // After another moment, reload screenshots
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadScreenshots()
            }
        }
    }
    
    func loadScreenshots() {
        isLoading = true
        screenshotsForSelectedDay = []
        
        // Calculate the start and end of the selected day
        let calendar = Calendar.current
        guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: selectedDay),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: selectedDay) else {
            isLoading = false
            return
        }
        
        NSLog("🖼 Loading screenshots from \(startOfDay) to \(endOfDay)")
        
        // Get screenshots from the database in a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let dbScreenshots = DatabaseManager.shared.getScreenshotsForTimeRange(startDate: startOfDay, endDate: endOfDay)
            
            // Return to main thread to update UI
            DispatchQueue.main.async {
                self.screenshotsForSelectedDay = dbScreenshots.sorted(by: { $0.timestamp > $1.timestamp })
                
                // Log path information
                for (index, screenshot) in self.screenshotsForSelectedDay.enumerated() {
                    let exists = FileManager.default.fileExists(atPath: screenshot.path)
                    NSLog("🖼 Screenshot \(index): path=\(screenshot.path), exists=\(exists)")
                }
                
                self.isLoading = false
                NSLog("🖼 Loaded \(self.screenshotsForSelectedDay.count) screenshots for \(self.selectedDay)")
            }
        }
    }
    
    func deleteScreenshot(_ screenshot: Screenshot) {
        // Remove from database
        _ = DatabaseManager.shared.deleteScreenshot(id: screenshot.id.uuidString)
        
        // Remove from UI
        if let index = screenshotsForSelectedDay.firstIndex(where: { $0.id == screenshot.id }) {
            screenshotsForSelectedDay.remove(at: index)
        }
        
        // Delete file
        do {
            try FileManager.default.removeItem(atPath: screenshot.path)
            print("Successfully deleted screenshot file at path: \(screenshot.path)")
        } catch {
            print("Error deleting screenshot file: \(error)")
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func startCapturingScreenshot() {
        isRecording = true
        ScreenshotManager.shared.startCapturing()
        
        // Update the UI after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadScreenshots()
        }
    }
    
    func stopCapturingScreenshot() {
        isRecording = false
        ScreenshotManager.shared.stopCapturing()
        
        // Update the UI after a short delay to show the latest screenshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadScreenshots()
        }
    }
}

// MARK: - Supporting Types

enum ViewMode {
    case grid
    case list
}

// MARK: - Preview

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
            .environmentObject(AppState.shared)
    }
} 