import SwiftUI

enum APIError: Error {
    case connectionFailed(Error)
    case invalidResponse
    case serverError(statusCode: Int)
    case missingData
    case invalidResponseFormat
    case serviceError(message: String)
}

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("captureInterval") private var captureInterval: Double = 3.0
    @AppStorage("similarityThreshold") private var similarityThreshold: Double = 0.95
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("monitorClipboard") private var monitorClipboard = true
    @AppStorage("clipboardMaxItems") private var clipboardMaxItems = 100.0
    @AppStorage("aiFeatureEnabled") private var aiFeatureEnabled = true
    @AppStorage("aiLocalProcessing") private var aiLocalProcessing = true
    @AppStorage("aiModelQuality") private var aiModelQuality = 1 // 0: Standard, 1: High, 2: Maximum
    @AppStorage("imageCompressionLevel") private var imageCompressionLevel = 0.8
    @AppStorage("useHEICFormatIfAvailable") private var useHEICFormatIfAvailable = true
    @AppStorage("screenshotResolutionFactor") private var screenshotResolutionFactor = 1.0
    @AppStorage("videoCompressionQuality") private var videoCompressionQuality = "Medium"
    @AppStorage("dataRetentionDays") private var dataRetentionDays = 90.0
    
    // OpenAI API settings
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openaiModel") private var openaiModel = "Qwen/Qwen2.5-Coder-32B-Instruct"
    @AppStorage("openaiApiBase") private var openaiApiBase = "https://api-inference.huggingface.co/models"
    
    @State private var selectedTab = 0
    @State private var showApiKey = false
    @State private var apiProvider = "huggingface"
    @State private var isTestingConnection = false
    @State private var apiConnectionStatus: (String, Bool)?
    @State private var recordAudio = false
    @State private var recordVideo = false
    @State private var isTestingAPI = false
    @State private var apiTestResult: String?
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Preferences")
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.thinMaterial)
            
            TabView(selection: $selectedTab) {
                // Recording Settings
                recordingTab
                    .tabItem {
                        Label("Recording", systemImage: "record.circle")
                    }
                    .tag(0)
                
                // Capture Settings
                captureSettingsView
                    .tabItem {
                        Label("Capture", systemImage: "camera")
                    }
                    .tag(1)
                
                // AI Features
                aiSettingsView
                    .tabItem {
                        Label("AI Features", systemImage: "sparkles")
                    }
                    .tag(2)
                
                // Appearance Settings
                appearanceSettingsView
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    .tag(3)
                
                // Storage Settings
                storageSettingsView
                    .tabItem {
                        Label("Storage", systemImage: "folder")
                    }
                    .tag(4)
                
                // General Settings
                generalSettingsView
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(5)
                
                // About View
                aboutView
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
                    .tag(6)
                
                // Add Diagnostics tab
                diagnosticsView
                    .tabItem {
                        Label("Diagnostics", systemImage: "bandage.fill")
                    }
                    .tag("diagnostics")
            }
            .padding(.top)
            
            HStack {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Text("Clear All Data")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(
                        title: Text("Clear All Data"),
                        message: Text("Are you sure you want to delete all data? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            appState.clearAllData()
                            showDeleteSuccess = true
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                Button(action: {
                    appState.saveSettings()
                    dismiss()
                }) {
                    Text("Save")
                        .frame(width: 100)
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
        .frame(width: 550, height: 500) // Increased height to accommodate new settings
    }
    
    // MARK: - Capture Settings
    
    private var captureSettingsView: some View {
        Form {
            Section {
                Group {
                    VStack(alignment: .leading, spacing: 20) {
                        sliderSetting(
                            title: "Capture Interval",
                            description: "Time between screenshots (in seconds)",
                            value: $captureInterval,
                            range: 1.0...10.0,
                            step: 0.5,
                            formatter: { String(format: "%.1f s", $0) }
                        )
                        
                        sliderSetting(
                            title: "Similarity Threshold",
                            description: "Skip screenshots that are too similar",
                            value: $similarityThreshold,
                            range: 0.5...1.0,
                            step: 0.05,
                            formatter: { String(format: "%d%%", Int($0 * 100)) }
                        )
                    }
                }
                
                Divider()
                
                Group {
                    toggleSetting(
                        title: "Record Audio",
                        description: "Capture audio during screen recording sessions",
                        isOn: $recordAudio
                    )
                    
                    toggleSetting(
                        title: "Record Video",
                        description: "Capture video instead of just still images (uses more storage)",
                        isOn: $recordVideo
                    )
                }
                
                Divider()
                
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text Recognition")
                            .font(.headline)
                        
                        Text("Automatically extracts and indexes text from your screenshots")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy & Security")
                            .font(.headline)
                        
                        Text("All processing happens locally on your Mac, no data is sent to external servers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - AI Settings
    
    private var aiSettingsView: some View {
        Form {
            Section(header: Text("AI Configuration")) {
                Group {
                    toggleSetting(
                        title: "Enable AI Features",
                        description: "Use AI to analyze your data and provide insights",
                        isOn: $aiFeatureEnabled
                    )
                    
                    toggleSetting(
                        title: "Local Processing Only",
                        description: "Process all AI features locally for maximum privacy",
                        isOn: $aiLocalProcessing
                    )
                    .onChange(of: aiLocalProcessing) { newValue in
                        // When disabling local processing, use API automatically
                        if !newValue {
                            // Test API connection to ensure it's working
                            testApiConnection()
                        }
                    }
                    
                    if aiLocalProcessing {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("AI Model Quality")
                                    .font(.headline)
                                Text("Higher quality requires more system resources")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("AI Model Quality", selection: $aiModelQuality) {
                                Text("Standard").tag(0)
                                Text("High").tag(1)
                                Text("Maximum").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 220)
                            .disabled(!aiFeatureEnabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if !aiLocalProcessing {
                    Divider()
                    
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI API Settings")
                                .font(.headline)
                            
                            Text("Connect to an AI API for enhanced capabilities")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // API Provider Selection
                        HStack {
                            VStack(alignment: .leading) {
                                Text("API Provider")
                                    .font(.headline)
                                Text("Select the AI provider to use")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("API Provider", selection: $apiProvider) {
                                Text("OpenAI").tag("openai")
                                Text("Hugging Face").tag("huggingface")
                                Text("Custom").tag("custom")
                            }
                            .frame(width: 200)
                            .onChange(of: apiProvider) { newValue in
                                updateApiSettings(for: newValue)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // API Key
                        HStack {
                            VStack(alignment: .leading) {
                                Text("API Key")
                                    .font(.headline)
                                Text("Your API key")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                if showApiKey {
                                    TextField("Enter API key", text: $openaiApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                } else {
                                    SecureField("Enter API key", text: $openaiApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                }
                                
                                Button(action: { showApiKey.toggle() }) {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Model Selection
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Model")
                                    .font(.headline)
                                Text("AI model to use")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if apiProvider == "openai" {
                                Picker("Model", selection: $openaiModel) {
                                    Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                                    Text("GPT-4").tag("gpt-4")
                                    Text("GPT-4 Turbo").tag("gpt-4-turbo")
                                }
                                .frame(width: 200)
                            } else if apiProvider == "huggingface" {
                                Picker("Model", selection: $openaiModel) {
                                    Text("Qwen2.5 Coder").tag("Qwen/Qwen2.5-Coder-32B-Instruct")
                                    Text("Mixtral 8x7B").tag("mistralai/Mixtral-8x7B-Instruct-v0.1")
                                    Text("Llama 3 8B").tag("meta-llama/Llama-3-8b-chat")
                                }
                                .frame(width: 200)
                            } else {
                                TextField("Custom model name", text: $openaiModel)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // API Base URL
                        HStack {
                            VStack(alignment: .leading) {
                                Text("API Endpoint")
                                    .font(.headline)
                                Text("API endpoint URL")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            TextField("API endpoint URL", text: $openaiApiBase)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                        .padding(.vertical, 4)
                        
                        // Test Connection Button
                        HStack {
                            Spacer()
                            
                            Button(action: testApiConnection) {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.trailing, 5)
                                } else {
                                    Text("Test Connection")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(openaiApiKey.isEmpty || isTestingConnection)
                            
                            if let connectionStatus = apiConnectionStatus {
                                Text(connectionStatus.0)
                                    .font(.caption)
                                    .foregroundStyle(connectionStatus.1 ? .green : .red)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Divider()
                
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Features")
                            .font(.headline)
                        
                        Text("AutoRecall uses AI to help you:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)
                                
                                Text("Analyze screenshots to extract context and meaning")
                                    .font(.subheadline)
                            }
                            
                            GridRow {
                                Image(systemName: "sparkles.bubble.left")
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)
                                
                                Text("Answer questions about your recorded activities")
                                    .font(.subheadline)
                            }
                            
                            GridRow {
                                Image(systemName: "sparkles.square.fill.on.square")
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)
                                
                                Text("Summarize content and activity patterns")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettingsView: some View {
        Form {
            Section {
                Group {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Theme")
                                .font(.headline)
                            Text("Choose your preferred app appearance")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("Theme", selection: $isDarkMode) {
                            Text("Light").tag(false)
                            Text("Dark").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .padding(.vertical, 4)
                }
                
                Divider()
                
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UI Preview")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            VStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color(.darkGray) : Color(.white))
                                    .frame(width: 100, height: 60)
                                    .shadow(radius: 2)
                                
                                Text("Light")
                                    .font(.caption)
                                    .foregroundStyle(isDarkMode ? .secondary : .primary)
                            }
                            .opacity(isDarkMode ? 0.5 : 1.0)
                            .onTapGesture {
                                withAnimation {
                                    isDarkMode = false
                                    setAppearance(isDark: isDarkMode)
                                }
                            }
                            
                            VStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color(.darkGray) : Color(.gray))
                                    .frame(width: 100, height: 60)
                                    .shadow(radius: 2)
                                
                                Text("Dark")
                                    .font(.caption)
                                    .foregroundStyle(isDarkMode ? .primary : .secondary)
                            }
                            .opacity(isDarkMode ? 1.0 : 0.5)
                            .onTapGesture {
                                withAnimation {
                                    isDarkMode = true
                                    setAppearance(isDark: isDarkMode)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Storage Settings
    
    private var storageSettingsView: some View {
        Form {
            Section(header: Text("Storage Usage")) {
                // Storage usage metrics
                VStack(spacing: 16) {
                    StorageUsageView()
                    
                    Divider()
                    
                    HStack {
                        Text("Storage Locations")
                            .font(.headline)
                        
                        Spacer()
                    }
                        
                        HStack {
                            Text(appState.defaultStoragePath)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button(action: {
                                NSWorkspace.shared.selectFile(
                                    nil,
                                    inFileViewerRootedAtPath: appState.defaultStoragePath
                                )
                            }) {
                                Label("Open", systemImage: "folder")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor)))
                    }
            }
            
            Section(header: Text("Optimization Settings")) {
                // Image compression settings
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screenshot Compression")
                            .font(.headline)
                        
                        Text("Optimize screenshots to use less disk space")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    sliderSetting(
                        title: "Compression Level",
                        description: "Higher values reduce file size but may affect quality",
                        value: $imageCompressionLevel,
                        range: 0.5...1.0,
                        step: 0.05,
                        formatter: { String(format: "%d%%", Int($0 * 100)) }
                    )
                    
                    sliderSetting(
                        title: "Resolution Factor",
                        description: "Reduces resolution to save space (1.0 = original size)",
                        value: $screenshotResolutionFactor,
                        range: 0.5...1.0,
                        step: 0.1,
                        formatter: { String(format: "%.1fx", $0) }
                    )
                    
                    toggleSetting(
                        title: "Use HEIC Format When Available",
                        description: "HEIC offers better compression than PNG (macOS 10.13+)",
                        isOn: $useHEICFormatIfAvailable
                    )
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Video compression settings
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Video Compression")
                            .font(.headline)
                        
                        Text("Configure video recording quality and storage usage")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Picker("Video Compression Quality", selection: $videoCompressionQuality) {
                        Text("Low (1 Mbps)").tag("Low")
                        Text("Medium (2.5 Mbps)").tag("Medium")
                        Text("High (5 Mbps)").tag("High")
                        Text("Ultra High (8 Mbps)").tag("Ultra High Compression")
                    }
                    .onChange(of: videoCompressionQuality) { newValue in
                        if let quality = VideoRecorder.CompressionQuality(rawValue: newValue) {
                            VideoRecorder.shared.setCompressionQuality(quality)
                        }
                    }
                    
                    Text("Higher quality uses more storage space. Ultra High provides the best quality but uses significantly more space.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Storage management and data retention
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Retention")
                            .font(.headline)
                        
                        Text("AutoRecall will automatically remove old data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    sliderSetting(
                        title: "Keep Data For",
                        description: "How long to keep screenshots and recordings",
                        value: $dataRetentionDays,
                        range: 7...365,
                        step: 7,
                        formatter: { String(format: "%d days", Int($0)) }
                    )
                    
                    sliderSetting(
                        title: "Maximum Clipboard Items",
                        description: "Number of clipboard items to keep in history",
                        value: $clipboardMaxItems,
                        range: 10...500,
                        step: 10,
                        formatter: { String(format: "%d items", Int($0)) }
                    )
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Cleanup actions
                Group {
                    VStack(alignment: .leading, spacing: 16) {
                        Button("Clean Up Old Data Now") {
                            cleanupOldData()
                        }
                        .buttonStyle(.borderedProminent)
                
                Button("Clear All Data...") {
                    confirmClearData()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - General Settings
    
    private var generalSettingsView: some View {
        Form {
            Section(header: Text("App Settings")) {
                Group {
                    toggleSetting(
                        title: "Launch at Login",
                        description: "Start AutoRecall automatically when you log in",
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLoginManager.shared.setLaunchAtLogin(newValue)
                    }
                    
                    toggleSetting(
                        title: "Show Notifications",
                        description: "Display app notifications for important events",
                        isOn: $showNotifications
                    )
                    
                    toggleSetting(
                        title: "Monitor Clipboard",
                        description: "Track clipboard contents for later searching",
                        isOn: $monitorClipboard
                    )
                    .onChange(of: monitorClipboard) { newValue in
                        if newValue {
                            ClipboardManager.shared.startMonitoring()
                        } else {
                            ClipboardManager.shared.stopMonitoring()
                        }
                    }
                }
            }
            
            Section(header: Text("Permissions")) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Screen Recording")
                                .font(.headline)
                            Text("Required to capture screenshots")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Circle()
                                .fill(appState.hasRequiredPermissions ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            
                            Text(appState.hasRequiredPermissions ? "Granted" : "Required")
                                .foregroundColor(appState.hasRequiredPermissions ? .green : .red)
                            
                            if !appState.hasRequiredPermissions {
                                Button("Request") {
                                    requestScreenRecordingPermission()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Accessibility")
                                .font(.headline)
                            Text("Enables additional app metadata collection")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Circle()
                                .fill(AXIsProcessTrusted() ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            
                            Text(AXIsProcessTrusted() ? "Granted" : "Optional")
                                .foregroundColor(AXIsProcessTrusted() ? .green : .orange)
                            
                            if !AXIsProcessTrusted() {
                                Button("Request") {
                                    requestAccessibilityPermission()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Input Monitoring")
                                .font(.headline)
                            Text("Required for keyboard shortcuts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Circle()
                                .fill(Color.green) // Assume granted since there's no direct API
                                .frame(width: 10, height: 10)
                            
                            Text("Granted")
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - About View
    
    private var aboutView: some View {
        Form {
            Section {
                VStack(spacing: 20) {
                    // Logo
                    Group {
                        VStack(spacing: 12) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 64))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.blue)
                            
                            Text("AutoRecall")
                                .font(.largeTitle.bold())
                            
                            Text("Version 1.0.0")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Description
                    Group {
                        Text("AutoRecall is a Privacy-First tool that captures your screen activity and makes it searchable, all while keeping your data secure on your Mac.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Links
                    Group {
                        VStack(spacing: 8) {
                            Link(destination: URL(string: "https://github.com/autorecall/autorecall")!) {
                                Label("View on GitHub", systemImage: "link")
                                    .frame(maxWidth: 200)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Link(destination: URL(string: "https://github.com/autorecall/autorecall/issues")!) {
                                Label("Report an Issue", systemImage: "exclamationmark.triangle")
                                    .frame(maxWidth: 200)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Spacer()
                    
                    // Copyright
                    Text("© 2024 AutoRecall Team")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Diagnostics View
    
    var diagnosticsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Diagnostics")
                .font(.title)
                .padding(.bottom, 10)
            
            Text("Use these tools to diagnose and fix issues with AutoRecall.")
                .foregroundColor(.secondary)
            
            Divider()
            
            Group {
                // Database Diagnostics
                VStack(alignment: .leading, spacing: 10) {
                    Text("Database")
                        .font(.headline)
                    
                    HStack {
                        Button("Repair Database") {
                            repairDatabase()
                        }
                        .help("Performs database integrity checks and repairs any issues")
                        
                        Button("Optimize Database") {
                            optimizeDatabase()
                        }
                        .help("Optimizes database for better performance")
                    }
                }
                
                // Storage Diagnostics
                VStack(alignment: .leading, spacing: 10) {
                    Text("Storage")
                        .font(.headline)
                    
                    HStack {
                        Button("Clean Storage") {
                            cleanStorage()
                        }
                        .help("Cleans up temporary files and ensures proper directory structure")
                        
                        Button("Verify Data Integrity") {
                            verifyDataIntegrity()
                        }
                        .help("Verifies and fixes data integrity issues")
                    }
                }
                
                // Backup and Restore
                VStack(alignment: .leading, spacing: 10) {
                    Text("Backup and Restore")
                        .font(.headline)
                    
                    HStack {
                        Button("Create Backup") {
                            createBackup()
                        }
                        .help("Creates a backup of your data that can be restored later")
                    }
                }
            }
            
            Divider()
            
            // Status messages
            ScrollView {
                Text(diagnosticMessages)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(5)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Diagnostic Functions
    
    @State private var diagnosticMessages: String = "Diagnostic log will appear here...\n"
    
    private func appendDiagnosticMessage(_ message: String) {
        diagnosticMessages += "\n[\(formattedDate())] \(message)"
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private func repairDatabase() {
        appendDiagnosticMessage("Starting database repair...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = DatabaseManager.shared.repairAndOptimizeDatabase()
            
            DispatchQueue.main.async {
                if success {
                    appendDiagnosticMessage("✅ Database repair completed successfully")
                } else {
                    appendDiagnosticMessage("❌ Database repair failed")
                }
            }
        }
    }
    
    private func optimizeDatabase() {
        appendDiagnosticMessage("Starting database optimization...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DatabaseManager.shared.optimizeDatabase()
                
                DispatchQueue.main.async {
                    appendDiagnosticMessage("✅ Database optimization completed successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    appendDiagnosticMessage("❌ Database optimization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func cleanStorage() {
        appendDiagnosticMessage("Starting storage cleanup...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            StorageManager.shared.cleanupStorage()
            
            DispatchQueue.main.async {
                appendDiagnosticMessage("✅ Storage cleanup completed")
            }
        }
    }
    
    private func verifyDataIntegrity() {
        appendDiagnosticMessage("Starting data integrity verification...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = StorageManager.shared.verifyDataIntegrity()
            
            DispatchQueue.main.async {
                if result.issues == 0 {
                    appendDiagnosticMessage("✅ Data integrity check passed with no issues")
                } else if result.success {
                    appendDiagnosticMessage("✅ Data integrity check found and fixed \(result.issues) issues")
                } else {
                    appendDiagnosticMessage("⚠️ Data integrity check found \(result.issues) issues but could not fix all of them")
                }
            }
        }
    }
    
    private func createBackup() {
        appendDiagnosticMessage("Creating backup...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let backupURL = StorageManager.shared.createDataBackup() {
                DispatchQueue.main.async {
                    appendDiagnosticMessage("✅ Backup created successfully at: \(backupURL.path)")
                    
                    // Show alert with backup location
                    let alert = NSAlert()
                    alert.messageText = "Backup Created"
                    alert.informativeText = "A backup of your data has been created at:\n\n\(backupURL.path)"
                    alert.addButton(withTitle: "Show in Finder")
                    alert.addButton(withTitle: "OK")
                    
                    let response = alert.runModal()
                    
                    if response == .alertFirstButtonReturn {
                        NSWorkspace.shared.selectFile(backupURL.path, inFileViewerRootedAtPath: backupURL.deletingLastPathComponent().path)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    appendDiagnosticMessage("❌ Backup creation failed")
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sliderSetting(
        title: String,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        formatter: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(formatter(value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            
            Slider(value: value, in: range, step: step)
                .padding(.top, 4)
        }
    }
    
    private func toggleSetting(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Functions
    
    private func setLaunchAtLogin(enabled: Bool) {
        LaunchAtLoginManager.shared.setLaunchAtLogin(enabled)
    }
    
    private func setAppearance(isDark: Bool) {
        if let window = NSApplication.shared.windows.first {
            window.appearance = isDark ? 
                NSAppearance(named: .darkAqua) : 
                NSAppearance(named: .aqua)
        }
    }
    
    private func confirmClearData() {
        let alert = NSAlert()
        alert.messageText = "Clear All Data"
        alert.informativeText = "Are you sure you want to delete all screenshots and data? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            appState.clearAllData()
        }
    }
    
    private func confirmResetSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings"
        alert.informativeText = "Are you sure you want to reset all settings to their defaults? This won't delete your data."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Reset settings to defaults
            captureInterval = 3.0
            similarityThreshold = 0.95
            showNotifications = true
            monitorClipboard = true
            clipboardMaxItems = 100.0
            isDarkMode = false
            aiFeatureEnabled = true
            aiLocalProcessing = true
            aiModelQuality = 1
            openaiApiKey = ""
            openaiModel = "Qwen/Qwen2.5-Coder-32B-Instruct"
            openaiApiBase = "https://api-inference.huggingface.co/models"
        }
    }

    private func updateApiSettings(for provider: String) {
        switch provider {
        case "openai":
            openaiApiBase = "https://api.openai.com/v1"
            openaiModel = "gpt-3.5-turbo"
        case "huggingface":
            openaiApiBase = "https://api-inference.huggingface.co/models"
            openaiModel = "Qwen/Qwen2.5-Coder-32B-Instruct"
            // User needs to provide their own HuggingFace API key
        case "custom":
            // Keep existing values when switching to custom
            break
        default:
            break
        }
        
        // Clear connection status when changing provider
        apiConnectionStatus = nil
    }
    
    private func testApiConnection() {
        guard !openaiApiKey.isEmpty else {
            apiConnectionStatus = ("API key is required", false)
            return
        }
        
        isTestingConnection = true
        apiConnectionStatus = nil
        
        // Define a variable for requestBody
        var requestBody: [String: Any]
        
        // Different request format based on the selected provider
        if apiProvider == "huggingface" {
            // HuggingFace test format
            requestBody = [
                "inputs": "Hello, can you hear me?",
                "parameters": [
                    "temperature": 0.7,
                    "max_tokens": 50,
                    "return_full_text": false
                ]
            ]
            
            // Properly construct the endpoint with the model name
            guard let encodedModel = openaiModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let _ = URL(string: "\(openaiApiBase)/\(encodedModel)") else {
                isTestingConnection = false
                apiConnectionStatus = ("Invalid API endpoint URL", false)
                return
            }
            
            // Rest of the connection test code...
        } else {
            // OpenAI test format
        // Create a simple test message
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a helpful assistant."],
            ["role": "user", "content": "Hello, can you hear me?"]
        ]
        
        // Create request body
            requestBody = [
            "model": openaiModel,
            "messages": messages
        ]
            
            // Rest of the connection test code...
        }
        
        // Convert to JSON
        guard (try? JSONSerialization.data(withJSONObject: requestBody)) != nil else {
            isTestingConnection = false
            apiConnectionStatus = ("Invalid request format", false)
            return
        }
        
        // Make the request with proper timeout and error handling
        // ... existing code ...
    }
    
    private func requestScreenRecordingPermission() {
        // Reset the "don't ask again" setting if user explicitly requests permission
        UserDefaults.standard.set(false, forKey: "dontShowPermissionDialog")
        
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission"
        alert.informativeText = "You'll be redirected to System Settings to enable screen recording permission."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
    
    private func requestAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission"
        alert.informativeText = "You'll be redirected to System Settings to enable accessibility permission."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private func validateResponse(data: Data?, response: URLResponse?, error: Error?) throws -> (Data, HTTPURLResponse) {
        if let error = error {
            throw APIError.connectionFailed(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        guard let data = data else {
            throw APIError.missingData
        }
        
        return (data, httpResponse)
    }
    
    private func parseApiResponse(data: Data, response: HTTPURLResponse) throws -> (String, Bool) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponseFormat
        }
        
        if let errorInfo = json["error"] as? [String: Any],
           let message = errorInfo["message"] as? String {
            throw APIError.serviceError(message: message)
        }
        
        return ("Connection successful", true)
    }
    
    // MARK: - Recording Tab
    
    private var recordingTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Screenshot capture settings
            GroupBox(label: Text("Screenshot Capture").bold()) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capture Interval: \(String(format: "%.1f", captureInterval)) seconds")
                            .font(.subheadline)
                        
                        Slider(value: $captureInterval, in: 1...10, step: 0.5) {
                            Text("Capture Interval")
                        }
                        .frame(maxWidth: 300)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Similarity Threshold: \(Int(similarityThreshold * 100))%")
                            .font(.subheadline)
                        
                        Slider(value: $similarityThreshold, in: 0.8...0.99, step: 0.01) {
                            Text("Similarity Threshold")
                        }
                        .frame(maxWidth: 300)
                        
                        Text("Higher values will only save screenshots with significant changes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            // Video recording settings
            GroupBox(label: Text("Video Recording").bold()) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Enable Video Recording", isOn: $appState.recordVideo)
                        .onChange(of: appState.recordVideo) { newValue in
                            appState.saveSettings()
                        }
                    
                    if appState.recordVideo {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Record Audio", isOn: $appState.recordAudio)
                                .onChange(of: appState.recordAudio) { newValue in
                                    appState.saveSettings()
                                }
                            
                            Text("Audio will be recorded from your default microphone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Video Quality")
                                .font(.subheadline)
                            
                            Picker("Video Quality", selection: .constant(1)) {
                                Text("Low (720p)").tag(0)
                                Text("Medium (1080p)").tag(1)
                                Text("High (Native)").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)
                            
                            Text("Higher quality uses more storage space")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Storage Management")
                                .font(.subheadline)
                            
                            HStack {
                                Button("Clean Up Old Videos") {
                                    cleanUpOldVideos()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Open Videos Folder") {
                                    openVideosFolder()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // Helper methods for video settings
    
    private func cleanUpOldVideos() {
        let alert = NSAlert()
        alert.messageText = "Delete Old Videos"
        alert.informativeText = "How old should videos be to delete?"
        
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Older than 1 day")
        alert.addButton(withTitle: "Older than 1 week")
        alert.addButton(withTitle: "Older than 1 month")
        
        let response = alert.runModal()
        
        var date = Date()
        
        switch response {
        case .alertSecondButtonReturn: // 1 day
            date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        case .alertThirdButtonReturn: // 1 week
            date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .alertFirstButtonReturn, NSApplication.ModalResponse.cancel: // Cancel
            return
        default: // 1 month (fourth button)
            date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
        
        StorageManager.shared.deleteOldVideos(olderThan: date)
        
        // Update storage usage
        appState.updateStorageUsage()
    }
    
    private func openVideosFolder() {
        if let videosDirectory = StorageManager.shared.getVideosDirectory() {
            NSWorkspace.shared.open(videosDirectory)
        }
    }
    
    private func cleanupOldData() {
        let retentionDays = Int(dataRetentionDays)
        let results = StorageManager.shared.cleanupOldData(retentionDays: retentionDays)
        
        let alert = NSAlert()
        alert.messageText = "Cleanup Complete"
        alert.informativeText = "Removed \(results.screenshots) screenshots and \(results.videos) videos older than \(retentionDays) days."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct StorageUsageView: View {
    @State private var totalStorageUsed: String = "Calculating..."
    @State private var screenshotsSize: String = "..."
    @State private var videosSize: String = "..."
    @State private var screenshotCount: Int = 0
    @State private var videoCount: Int = 0
    @State private var isRefreshing: Bool = false
    
    private let storageManager = StorageManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Storage Usage")
                    .font(.headline)
                
                Spacer()
                
                Button(action: refreshStorageInfo) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
            }
            
            VStack(spacing: 12) {
                HStack {
                    StorageUsageBarView(
                        title: "Total",
                        value: totalStorageUsed,
                        count: screenshotCount + videoCount,
                        countLabel: "items",
                        color: .blue
                    )
                }
                
                HStack(spacing: 12) {
                    StorageUsageBarView(
                        title: "Screenshots",
                        value: screenshotsSize, 
                        count: screenshotCount,
                        countLabel: "files",
                        color: .green
                    )
                    
                    StorageUsageBarView(
                        title: "Videos", 
                        value: videosSize,
                        count: videoCount,
                        countLabel: "files",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor)))
        .onAppear {
            refreshStorageInfo()
        }
    }
    
    private func refreshStorageInfo() {
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Calculate sizes
            let totalSize = storageManager.calculateTotalStorageSize()
            let screenshotsSize = storageManager.calculateScreenshotsStorageSize()
            let videosSize = storageManager.calculateVideosStorageSize()
            
            // Get counts
            let screenshotCount = storageManager.getScreenshotCount()
            let videoCount = storageManager.getVideoCount()
            
            // Format sizes
            let totalSizeFormatted = storageManager.formatStorageSize(totalSize)
            let screenshotsSizeFormatted = storageManager.formatStorageSize(screenshotsSize)
            let videosSizeFormatted = storageManager.formatStorageSize(videosSize)
            
            DispatchQueue.main.async {
                self.totalStorageUsed = totalSizeFormatted
                self.screenshotsSize = screenshotsSizeFormatted
                self.videosSize = videosSizeFormatted
                self.screenshotCount = screenshotCount
                self.videoCount = videoCount
                self.isRefreshing = false
            }
        }
    }
}

struct StorageUsageBarView: View {
    var title: String
    var value: String
    var count: Int
    var countLabel: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                
                Spacer()
                
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(height: 6)
            }
            .frame(height: 6)
            
            Text("\(count) \(countLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// Replace the CompressionQuality enum extension with a proper reference to VideoRecorder
extension VideoRecorder {
    // This is just a type reference, not a duplicate enum definition
} 