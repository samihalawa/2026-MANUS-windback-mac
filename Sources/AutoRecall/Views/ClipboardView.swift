import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var clipboardItems: [ClipboardItem] = []
    @State private var isMonitoring = true
    @State private var isAIInsightsVisible = false
    @State private var isGeneratingInsights = false
    @State private var insights: [String] = []
    @State private var showCopyToast: Bool = false
    @State private var lastCopiedText: String = ""
    @StateObject private var clipboardManager = ClipboardManager.shared
    
    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.items
        } else {
            return clipboardManager.items.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            
            // Toggle for clipboard monitoring
            HStack {
                Text("Monitor Clipboard")
                Spacer()
                Toggle("", isOn: $isMonitoring)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: isMonitoring) { newValue in
                        if newValue {
                            clipboardManager.startMonitoring()
                        } else {
                            clipboardManager.stopMonitoring()
                        }
                    }
            }
            .padding(.horizontal)
            
            // List of clipboard items
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    Text("No clipboard items found")
                        .foregroundColor(.gray)
                    if !isMonitoring {
                        Text("Enable 'Monitor Clipboard' to start capturing copied items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                    
                    // Add a button to manually add content
                    Button(action: {
                        showAddEntryDialog()
                    }) {
                        Label("Add Manual Entry", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                    Spacer()
                }
            } else {
                List(filteredItems) { item in
                    ClipboardItemView(item: item)
                        .contextMenu {
                            Button(action: {
                                copyToClipboard(item)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                deleteItem(item)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            copyToClipboard(item)
                        }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Clipboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showAddEntryDialog()
                }) {
                    Label("Add", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: refreshItems) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: clearClipboardHistory) {
                        Label("Clear History", systemImage: "trash")
                    }
                    
                    Toggle(isOn: $isAIInsightsVisible) {
                        Label("AI Insights", systemImage: "brain")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(
            Group {
                if showCopyToast {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Copied to clipboard")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding()
                            Spacer()
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showCopyToast)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopyToast = false
                        }
                    }
                }
            }
        )
        .onChange(of: clipboardManager.items) { _ in
            self.clipboardItems = clipboardManager.items
        }
        .onAppear {
            // Always start monitoring if not already monitoring
            if !isMonitoring {
                isMonitoring = true
                clipboardManager.startMonitoring()
            }
            
            // Force refresh items on appear
            self.clipboardItems = clipboardManager.items
            
            // For first launch, copy current clipboard to start history
            if clipboardManager.items.isEmpty {
                clipboardManager.checkClipboardManually()
            }
            
            // Refresh items explicitly
            refreshItems()
        }
        .onDisappear {
            // Don't stop monitoring when view disappears
            // clipboardManager.stopMonitoring()
        }
    }
    
    private func refreshItems() {
        // Explicitly request items from the ClipboardManager
        clipboardManager.refreshItems()
        self.clipboardItems = clipboardManager.items
    }
    
    private func copyToClipboard(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item)
        lastCopiedText = item.content
        showCopyToast = true
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item.id)
        refreshItems()
    }
    
    private func clearClipboardHistory() {
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History"
        alert.informativeText = "Are you sure you want to clear all clipboard history? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Get all clipboard items
            let items = clipboardManager.items
            
            // Delete each item
            for item in items {
                // Call StorageManager to delete
                _ = StorageManager.shared.deleteScreenshot(id: item.id)
            }
            
            // Refresh clipboard items
            clipboardManager.refreshItems()
            self.clipboardItems = clipboardManager.items
            
            NSLog("Clipboard history cleared")
        }
    }
    
    // Add this function to show a dialog to manually add clipboard content
    private func showAddEntryDialog() {
        let alert = NSAlert()
        alert.messageText = "Add Clipboard Entry"
        alert.informativeText = "Enter text to add to your clipboard history"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "Enter text, URL, or file path"
        
        alert.accessoryView = textField
        alert.addButton(withTitle: "Add as Text")
        alert.addButton(withTitle: "Add as URL")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        let content = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if content.isEmpty { return }
        
        if response == .alertFirstButtonReturn {
            // Add as text
            clipboardManager.createManualClipboardEntry(content: content, type: .text)
            refreshItems()
        } else if response == .alertSecondButtonReturn {
            // Add as URL
            clipboardManager.createManualClipboardEntry(content: content, type: .url)
            refreshItems()
        }
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack {
            Image(systemName: item.type.icon)
                .foregroundColor(item.type.color)
            
            VStack(alignment: .leading) {
                Text(item.content)
                    .lineLimit(2)
                Text(item.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// Define ClipboardFilter enum
enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case images = "Images"
    case urls = "URLs"
    case files = "Files"
    
    var id: String { self.rawValue }
}

// MARK: - Supporting Types

// MARK: - Preview

struct ClipboardView_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardView()
            .environmentObject(AppState.shared)
    }
} 