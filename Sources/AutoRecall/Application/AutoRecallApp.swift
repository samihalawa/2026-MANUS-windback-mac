import SwiftUI
import UserNotifications

struct AutoRecallApp: App {
    @StateObject private var appState = AppState.shared
    @State private var selectedTab: TabIdentifier = .timeline
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    setupApp()
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    appState.selectedTab = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Take Screenshot") {
                    Task {
                        ScreenshotManager.shared.captureSingleScreenshot()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Start/Stop Recording") {
                    toggleRecording()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .sidebar) {
                Button("Global Search") {
                    appState.isGlobalSearchActive = true
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
    
    private func setupApp() {
        // Initialize managers
        _ = DatabaseManager.shared
        _ = ScreenshotManager.shared
        _ = ClipboardManager.shared
        _ = TextInputManager.shared
        
        // Start monitoring text input
        TextInputManager.shared.startMonitoring()
    }
    
    private func toggleRecording() {
        if VideoRecorder.shared.isRecording {
            Task {
                await VideoRecorder.shared.stopRecording()
            }
        } else {
            Task {
                await VideoRecorder.shared.startRecording()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AutoRecallApp.TabIdentifier = .timeline
    @State private var sidebarWidth: CGFloat = 70
    @State private var isExpanded: Bool = false
    @State private var isStatusExpanded: Bool = false
    @State private var globalSearch: String = ""
    @State private var isFocused: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            NavigationSplitView {
                // Sidebar
                VStack(spacing: 0) {
                    // App logo/branding at top
                    VStack(spacing: 4) {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 5)
                            .padding(.top, 16)
                        
                        if isExpanded {
                            Text("AutoRecall")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(.labelColor))
                        }
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Global search if sidebar is expanded
                    if isExpanded {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                            
                            TextField("Search everything...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .onSubmit {
                                    selectedTab = .search
                                    NotificationCenter.default.post(
                                        name: Notification.Name("SetGlobalSearch"),
                                        object: searchText
                                    )
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.textBackgroundColor).opacity(0.8))
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    
                    // Tab buttons with modern design
                    VStack(spacing: 4) {
                        ForEach(AutoRecallApp.TabIdentifier.allCases, id: \.self) { tab in
                            Button(action: { withAnimation { selectedTab = tab } }) {
                                HStack(spacing: 12) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(selectedTab == tab ? tab.color : .secondary)
                                        .frame(width: 26)
                                    
                                    if isExpanded {
                                        Text(tab.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedTab == tab ? tab.color : .primary)
                                        
                                        Spacer()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
                                .padding(.vertical, 12)
                                .padding(.horizontal, isExpanded ? 16 : 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedTab == tab ? 
                                            tab.color.opacity(0.15) : 
                                            Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                            .help(tab.title)
                        }
                    }
                    
                    Spacer()
                    
                    // Recording status section with modern design
                    VStack(spacing: 8) {
                        Button(action: {
                            withAnimation {
                                isStatusExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(appState.isRecording ? Color.red : Color.gray)
                                    .frame(width: 8, height: 8)
                                
                                if isExpanded {
                                    Text("Status")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: isStatusExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, isExpanded ? 16 : 8)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        if isStatusExpanded && isExpanded {
                            recordingControlsView
                        }
                    }
                    .padding(.bottom, 4)
                    
                    Divider()
                    
                    // Bottom buttons section (settings, etc)
                    VStack(spacing: 0) {
                        Button(action: {
                            NSApp.sendAction(Selector(("showPreferences")), to: nil, from: nil)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                
                                if isExpanded {
                                    Text("Preferences")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
                            .padding(.vertical, 10)
                            .padding(.horizontal, isExpanded ? 16 : 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .help("Preferences")
                        
                        Button(action: {
                            NSApp.sendAction(Selector(("openAbout:")), to: nil, from: nil)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                
                                if isExpanded {
                                    Text("About")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
                            .padding(.vertical, 10)
                            .padding(.horizontal, isExpanded ? 16 : 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 16)
                        .help("About AutoRecall")
                    }
                }
                .frame(width: sidebarWidth)
                .background(
                    ZStack {
                        Color(.windowBackgroundColor).opacity(0.95)
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
                )
                .overlay(
                    HStack {
                        Spacer()
                        // Resize handle
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 1)
                    }
                )
            } detail: {
                ZStack {
                    // Background color based on tab with gradient effect
                    LinearGradient(
                        colors: [
                            selectedTab.color.opacity(0.05),
                            selectedTab.color.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Dynamic content based on selected tab with smooth transitions
                    Group {
                        switch selectedTab {
                        case .timeline:
                            TimelineView()
                                .transition(.opacity)
                        case .search:
                            SearchView()
                                .transition(.opacity)
                        case .clipboard:
                            ClipboardView()
                                .transition(.opacity)
                        case .textInput:
                            TextInputView()
                                .transition(.opacity)
                        case .videos:
                            VideosView()
                                .transition(.opacity)
                        case .aiAssistant:
                            AIAssistantView()
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Global search overlay
                    if appState.isGlobalSearchActive {
                        GlobalSearchView(isActive: $appState.isGlobalSearchActive)
                            .frame(width: 600, height: 400)
                            .transition(.move(edge: .top))
                    }
                }
            }
            .toolbar {
                // Modern toolbar in detail view with title and actions
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedTab.icon)
                            .font(.headline)
                            .foregroundColor(selectedTab.color)
                        
                        Text(selectedTab.title)
                            .font(.headline)
                            .foregroundColor(selectedTab.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(selectedTab.color.opacity(0.1))
                    )
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if selectedTab == .timeline {
                            Menu {
                                Button("Today") {
                                    NotificationCenter.default.post(name: Notification.Name("SetTimelineDate"), object: Date())
                                }
                                Button("Yesterday") {
                                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                                    NotificationCenter.default.post(name: Notification.Name("SetTimelineDate"), object: yesterday)
                                }
                                Button("Last Week") {
                                    let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
                                    NotificationCenter.default.post(name: Notification.Name("SetTimelineDate"), object: lastWeek)
                                }
                                
                                Divider()
                                
                                Button("Custom Date...") {
                                    // Would show date picker in a popover
                                }
                            } label: {
                                Label("Date", systemImage: "calendar")
                            }
                            .menuStyle(.borderedButton)
                            
                            // View mode switcher
                            Picker("View", selection: .constant(0)) {
                                Text("Grid").tag(0)
                                Text("List").tag(1)
                                Text("Timeline").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        } else if selectedTab == .search {
                            Button(action: {
                                NotificationCenter.default.post(name: Notification.Name("ClearSearch"), object: nil)
                            }) {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .help("Clear search")
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            // Advanced search button
                            Button(action: {
                                // Would show advanced search options
                            }) {
                                Label("Advanced", systemImage: "slider.horizontal.3")
                            }
                            .help("Advanced search options")
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else if selectedTab == .aiAssistant {
                            Button(action: {
                                NotificationCenter.default.post(name: Notification.Name("NewAIChat"), object: nil)
                            }) {
                                Label("New Chat", systemImage: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .help("Start a new chat")
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .padding(.horizontal, 4)
                            
                            Button(action: {
                                NotificationCenter.default.post(name: Notification.Name("ClearAIChat"), object: nil)
                            }) {
                                Label("Clear", systemImage: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .help("Clear conversation")
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: {
                        appState.isGlobalSearchActive = true
                    }) {
                        Label("Global Search", systemImage: "magnifyingglass")
                    }
                    .help("Global Search (⌘⇧F)")
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                }
            }
            
            // Sidebar resize handle
            Rectangle()
                .fill(Color.clear)
                .frame(width: 10)
                .contentShape(Rectangle())
                .position(x: sidebarWidth, y: (NSScreen.main?.frame.height ?? 800) / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = max(70, min(240, sidebarWidth + value.translation.width))
                            sidebarWidth = newWidth
                            isExpanded = newWidth > 100
                        }
                )
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchTab"))) { notification in
            if let tab = notification.object as? AutoRecallApp.TabIdentifier {
                withAnimation {
                    selectedTab = tab
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ActivateGlobalSearch"))) { _ in
            withAnimation {
                appState.isGlobalSearchActive = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GlobalSearch"))) { notification in
            if let searchQuery = notification.object as? String {
                searchText = searchQuery
                // Perform search with this query
            }
        }
    }
    
    private var recordingControlsView: some View {
        Group {
            VStack(spacing: 16) {
                recordingStatusRow
                
                recordingInfoRow
                
                recordingOptionsRow
            }
        }
    }
    
    private var recordingStatusRow: some View {
        HStack(spacing: 12) {
            // Recording status indicator with enhanced visibility
            Circle()
                .fill(appState.isRecording ? Color.red : Color.gray)
                .frame(width: 12, height: 12)
                .padding(4)
                .background(
                    Circle()
                        .stroke(appState.isRecording ? Color.red.opacity(0.5) : Color.gray.opacity(0.5), lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.3), value: appState.isRecording)
            
            Text(appState.isRecording ? "Recording Active" : "Recording Paused")
                .font(.headline)
                .foregroundColor(appState.isRecording ? .red : .primary)
            
            Spacer()
            
            // Enhanced buttons with better visibility
            Button(action: {
                if appState.isRecording {
                    pauseRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack {
                    Image(systemName: appState.isRecording ? "pause.fill" : "record.circle")
                        .font(.system(size: 18, weight: .bold))
                    Text(appState.isRecording ? "Pause" : "Record")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(appState.isRecording ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var recordingInfoRow: some View {
        HStack(spacing: 16) {
            Button(action: {
                stopRecording()
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Stop")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!appState.isRecording)
            .opacity(!appState.isRecording ? 0.5 : 1.0)
            
            Spacer()
            
            // Display recording duration if active
            if appState.isRecording {
                HStack {
                    Image(systemName: "clock")
                    Text("00:00:00") // Placeholder for recording duration
                        .monospacedDigit()
                        .font(.subheadline.monospacedDigit())
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var recordingOptionsRow: some View {
        HStack(spacing: 16) {
            Toggle(isOn: .constant(true)) { // Using constant instead of $appState.recordAudio
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                    Text("Audio")
                        .font(.subheadline)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .disabled(appState.isRecording)
            
            Toggle(isOn: .constant(false)) { // Using constant instead of $appState.recordVideo
                HStack {
                    Image(systemName: "video.slash")
                        .foregroundColor(.gray)
                    Text("Video")
                        .font(.subheadline)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .disabled(appState.isRecording)
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // Start recording function
    func startRecording() {
        if !hasScreenCapturePermission() {
            requestScreenCapturePermission()
            return
        }
        
        // Audio permission check is not needed on macOS, but we'll keep a simplified version
        
        // Start the recording process
        appState.isRecording = true
        appState.isPaused = false
        appState.recordingStartTime = Date()
        
        // Start the timer to update the duration
        appState.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateRecordingDuration()
        }
        
        // Call the screenshot manager
        ScreenshotManager.shared.startCapturing()
        
        // Schedule a reminder notification after an hour
        NotificationManager.shared.scheduleRecordingReminder()
        
        // Post notification that recording has started
        NotificationCenter.default.post(
            name: NSNotification.Name("RecordingStatusChanged"), 
            object: true
        )
        
        // Show notification
        NotificationManager.shared.showNotification(
            title: "Recording Started",
            body: "AutoRecall is now recording your screen activity",
            identifier: "recording-status"
        )
    }
    
    // Check for screen capture permission
    private func hasScreenCapturePermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    // Request screen capture permission
    private func requestScreenCapturePermission() {
        // Show a dialog to guide the user
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "AutoRecall needs permission to record your screen. You'll be redirected to System Settings to enable this permission."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            CGRequestScreenCaptureAccess()
        }
    }
    
    // Check for audio permission - simplified for macOS
    private func hasAudioPermission() -> Bool {
        // macOS doesn't have the same audio permission model as iOS
        return true
    }
    
    // Request audio permission - simplified for macOS
    private func requestAudioPermission() {
        // No need to request permission on macOS
        startRecording()
    }
    
    private func pauseRecording() {
        ScreenshotManager.shared.pauseCapturing()
        appState.isRecording = false
        appState.isPaused = true
        
        // Update menu bar status
        MenuBarManager.shared.updateRecordingStatus(isRecording: false)
        
        // Post notification that recording has stopped
        NotificationCenter.default.post(
            name: Notification.Name("RecordingStatusChanged"), 
            object: false
        )
        
        // Show notification
        NotificationManager.shared.showNotification(
            title: "Recording Paused",
            body: "Screen recording has been paused",
            identifier: "recording-status"
        )
    }
    
    private func stopRecording() {
        ScreenshotManager.shared.stopCapturing()
        appState.isRecording = false
        appState.isPaused = false
        
        // Stop and invalidate the timer
        appState.recordingTimer?.invalidate()
        appState.recordingTimer = nil
        appState.recordingDuration = 0
        
        // Update menu bar status
        MenuBarManager.shared.updateRecordingStatus(isRecording: false)
        
        // Post notification that recording has stopped
        NotificationCenter.default.post(
            name: Notification.Name("RecordingStatusChanged"), 
            object: false
        )
        
        // Show notification
        NotificationManager.shared.showNotification(
            title: "Recording Stopped",
            body: "Screen recording has been stopped and saved",
            identifier: "recording-status"
        )
    }
    
    private func updateRecordingDuration() {
        if let startTime = appState.recordingStartTime as Date? {
            appState.recordingDuration = Date().timeIntervalSince(startTime)
        }
    }
}

// Global Search View
struct GlobalSearchView: View {
    @Binding var isActive: Bool
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedResult: SearchResult?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search everything...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _ in
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color(.textBackgroundColor))
            
            Divider()
            
            // Results
            if isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults, id: \.id, selection: $selectedResult) { result in
                    SearchResultRow(result: result)
                }
            }
        }
        .frame(width: 600, height: 400)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        
        // Perform search across all data types
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [SearchResult] = []
            
            // Search text inputs
            let textInputs = DatabaseManager.shared.searchTextInputs(query: searchText)
            results += textInputs.map { textInput in
                SearchResult(
                    id: "text_\(textInput.id)",
                    title: textInput.text,
                    subtitle: "\(textInput.appName) - \(textInput.windowTitle)",
                    type: .textInput,
                    date: textInput.timestamp,
                    object: textInput
                )
            }
            
            // Search screenshots
            let screenshots = DatabaseManager.shared.searchScreenshots(query: searchText)
            results += screenshots.map { screenshot in
                SearchResult(
                    id: "screenshot_\(screenshot.id)",
                    title: "Screenshot",
                    subtitle: screenshot.path,
                    type: .screenshot,
                    date: screenshot.timestamp,
                    object: screenshot
                )
            }
            
            // Search clipboard items
            let clipboardItems = DatabaseManager.shared.searchClipboardItems(query: searchText)
            results += clipboardItems.map { item in
                SearchResult(
                    id: "clipboard_\(item.id)",
                    title: item.text ?? "Clipboard Item",
                    subtitle: item.type.rawValue,
                    type: .clipboard,
                    date: item.timestamp,
                    object: item
                )
            }
            
            // Sort results by date
            results.sort { $0.date > $1.date }
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isLoading = false
            }
        }
    }
}

struct SearchResult: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let type: SearchResultType
    let date: Date
    let object: Any
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SearchResultType {
    case textInput
    case screenshot
    case clipboard
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.headline)
            
            Text(result.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(result.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// AI Assistant View (with full implementation)
struct AIAssistantView: View {
    @State private var inputText: String = ""
    @State private var conversations: [Message] = [
        Message(isUser: false, content: "👋 Welcome to AutoRecall! I'm your AI assistant powered by Hugging Face models. I can help you search through your screen recordings, summarize information, and answer questions about what you've captured. All processing happens locally for maximum privacy.", date: Date().addingTimeInterval(-60))
    ]
    @State private var isThinking = false
    @State private var errorMessage: String?
    @State private var lastErrorMessage: Message?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var shouldScrollToBottom = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(conversations) { message in
                            MessageView(message: message)
                                .padding(.horizontal)
                                .id(message.id) // Set ID for scrolling
                        }
                        
                        if isThinking {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.purple)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(.purple.opacity(0.1)))
                                
                                ProgressView()
                                    .scaleEffect(0.7)
                                
                                Text("Thinking...")
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                            }
                            .padding()
                            .padding(.leading, 8)
                            .id("thinking") // Set ID for scrolling
                        }
                        
                        if let error = errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.orange)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(.orange.opacity(0.1)))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(error)
                                        .foregroundStyle(.secondary)
                                    
                                    Button("Retry") {
                                        errorMessage = nil
                                        if let lastMessage = lastErrorMessage {
                                            processMessageWithAIManager(lastMessage)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.orange)
                                }
                                
                                Spacer()
                                
                                Button(action: { errorMessage = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(.orange.opacity(0.1)))
                            .padding(.horizontal)
                            .id("error") // Set ID for scrolling
                        }
                        
                        // Empty spacer view at the bottom for scrolling
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.vertical)
                }
                .onAppear {
                    scrollProxy = proxy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            scrollProxy?.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: conversations.count) { _ in
                    shouldScrollToBottom = true
                }
                .onChange(of: isThinking) { _ in
                    shouldScrollToBottom = true
                }
                .onChange(of: errorMessage) { _ in
                    shouldScrollToBottom = true
                }
            }
            
            Divider()
            
            // Input area
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Ask anything about what you've seen, copied, or worked on...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 10)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $inputText)
                        .font(.body)
                        .padding(5)
                        .frame(minHeight: 40, maxHeight: 120)
                        .onChange(of: inputText) { newValue in
                            // Detect Command+Return or Shift+Return to send message
                            if newValue.contains("\r") {
                                inputText = newValue.replacingOccurrences(of: "\r", with: "")
                                sendMessage()
                            }
                        }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.textBackgroundColor))
                )
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 40))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.purple)
                }
                .disabled(inputText.isEmpty || isThinking)
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
                .padding(.bottom, 8)
                .help("Send message (⌘+Return)")
                
                // Clear chat button
                Button(action: {
                    withAnimation {
                        conversations = [
                            Message(isUser: false, content: "👋 Welcome to AutoRecall! I'm your AI assistant powered by Hugging Face models. I can help you search through your screen recordings, summarize information, and answer questions about what you've captured. All processing happens locally for maximum privacy.", date: Date())
                        ]
                        errorMessage = nil
                        isThinking = false
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                .help("Clear conversation")
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewAIChat"))) { _ in
            conversations = [
                Message(isUser: false, content: "👋 Welcome to AutoRecall! I'm your AI assistant powered by Hugging Face models. I can help you search through your screen recordings, summarize information, and answer questions about what you've captured. All processing happens locally for maximum privacy.", date: Date())
            ]
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClearAIChat"))) { _ in
            conversations = []
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SummarizeTimeline"))) { _ in
            let userMessage = Message(isUser: true, content: "Summarize my timeline activity today", date: Date())
            conversations.append(userMessage)
            processMessageWithAIManager(userMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AnalyzeClipboard"))) { _ in
            let userMessage = Message(isUser: true, content: "Analyze my clipboard history", date: Date())
            conversations.append(userMessage)
            processMessageWithAIManager(userMessage)
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty, !isThinking else { return }
        
        let userMessage = Message(isUser: true, content: inputText, date: Date())
        
        withAnimation {
            conversations.append(userMessage)
            shouldScrollToBottom = true
        }
        
        inputText = ""
        
        processMessageWithAIManager(userMessage)
    }
    
    private func processMessageWithAIManager(_ userMessage: Message) {
        // Indicate AI is thinking
        withAnimation {
            isThinking = true
            errorMessage = nil
            lastErrorMessage = userMessage
            shouldScrollToBottom = true
        }
        
        // Check if the user's message is very short and might lead to generic responses
        let messageContent = userMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if messageContent.count < 5 {
            // For very short messages, provide guidance instead of sending to AI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isThinking = false
                    let helpMessage = Message(
                        isUser: false, 
                        content: "I notice your message is very short. To get the most helpful response, please try asking a more specific question about your screen recordings, clipboard history, or something you've seen on your screen recently.", 
                        date: Date()
                    )
                    conversations.append(helpMessage)
                    shouldScrollToBottom = true
                }
            }
            return
        }
        
        // Check if this is a direct follow-up question about the AI's behavior
        let lowercaseContent = messageContent.lowercased()
        if lowercaseContent.contains("why") && (
            lowercaseContent.contains("same") || 
            lowercaseContent.contains("repeat") || 
            lowercaseContent.contains("again")
        ) {
            // For questions about repetitive responses, provide direct feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isThinking = false
                    let explainMessage = Message(
                        isUser: false,
                        content: "I apologize if my previous responses seemed repetitive. I'm designed to provide information based on your screen recordings and clipboard history. To get more varied and helpful responses, try asking specific questions about your data, such as 'What was I working on at 2pm?' or 'Show me the code I copied yesterday.'",
                        date: Date()
                    )
                    conversations.append(explainMessage)
                    shouldScrollToBottom = true
                }
            }
            return
        }
        
        // Process message with AIManager (for normal queries)
        AIManager.shared.processMessage(
            userMessage.content,
            previousMessages: conversations.filter { $0.id != userMessage.id }, // Exclude current message to avoid duplication
            completion: { result in
                // AI is no longer thinking
                DispatchQueue.main.async {
                    withAnimation {
                        isThinking = false
                        
                        switch result {
                        case .success(let response):
                            generateResponse(cleanHuggingFaceResponse(response))
                            lastErrorMessage = nil
                        case .failure(let error):
                            // Show error with option to retry
                            errorMessage = "Error: \(error.localizedDescription). Click retry or check your API settings in preferences."
                            NSLog("AI processing error: \(error.localizedDescription)")
                        }
                        
                        shouldScrollToBottom = true
                    }
                }
            }
        )
    }
    
    private func generateResponse(_ content: String) {
        let aiMessage = Message(isUser: false, content: content, date: Date())
        conversations.append(aiMessage)
    }
    
    // Helper to clean up Hugging Face responses which might contain artifacts
    private func cleanHuggingFaceResponse(_ response: String) -> String {
        var cleanedResponse = response
        
        // Remove any "<|assistant|>" or similar tags that might be in the response
        let patterns = ["<|assistant|>", "<|system|>", "<|user|>", "<|endoftext|>", "[/INST]", "[INST]", "Assistant:"]
        for pattern in patterns {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: pattern, with: "")
        }
        
        // Trim whitespace
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the response starts with the user's message, try to extract just the assistant's response
        if let assistantPart = cleanedResponse.components(separatedBy: "Assistant:").last {
            cleanedResponse = assistantPart.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return cleanedResponse
    }
}

// Message model
struct Message: Identifiable {
    let id = UUID()
    let isUser: Bool
    let content: String
    let date: Date
}

// Message View
struct MessageView: View {
    let message: Message
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar/icon
            if !message.isUser {
                Image(systemName: "brain")
                    .font(.system(size: 16))
                    .foregroundStyle(.purple)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.purple.opacity(0.1)))
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Content bubble
                Text(.init(message.content))  // Use .init to support markdown formatting
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? 
                                 Color.blue.opacity(0.1) : 
                                 Color(.windowBackgroundColor).opacity(0.7))
                    )
                    .frame(maxWidth: 500, alignment: message.isUser ? .trailing : .leading)
                
                // Timestamp
                Text(timeFormatter.string(from: message.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if message.isUser {
                // User avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.blue.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            }) {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
    }
} 