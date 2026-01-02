import SwiftUI

struct TextInputView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var textInputs: [TextInput] = []
    @State private var selectedTextInput: TextInput?
    @State private var showingDeleteAlert = false
    @State private var selectedTimeFilter: TimeFilter = .today
    @State private var isLoading = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    enum TimeFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case yesterday = "Yesterday"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Time Range", selection: $selectedTimeFilter) {
                    ForEach(TimeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedTimeFilter) { _ in
                    loadTextInputs()
                }
                
                Spacer()
                
                TextField("Search text inputs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                    .padding(.trailing)
                    .onChange(of: searchText) { _ in
                        if searchText.isEmpty {
                            loadTextInputs()
                        } else {
                            searchTextInputs()
                        }
                    }
                
                Button(action: {
                    loadTextInputs()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing)
            }
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor))
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading text inputs...")
                Spacer()
            } else if textInputs.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No text inputs found")
                        .font(.headline)
                        .padding(.top, 10)
                    Text("Text inputs from your applications will appear here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                List {
                    ForEach(textInputs) { textInput in
                        TextInputRow(textInput: textInput)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTextInput = textInput
                            }
                            .contextMenu {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(textInput.text, forType: .string)
                                }) {
                                    Label("Copy Text", systemImage: "doc.on.doc")
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    selectedTextInput = textInput
                                    showingDeleteAlert = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .alert(isPresented: $showingDeleteAlert) {
                    Alert(
                        title: Text("Delete Text Input"),
                        message: Text("Are you sure you want to delete this text input? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            if let textInput = selectedTextInput {
                                deleteTextInput(id: textInput.id)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .onAppear {
            loadTextInputs()
        }
    }
    
    private func loadTextInputs() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let startDate: Date
            let endDate = Date()
            
            switch selectedTimeFilter {
            case .today:
                startDate = Calendar.current.startOfDay(for: Date())
            case .yesterday:
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                startDate = Calendar.current.startOfDay(for: yesterday)
            case .week:
                startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            case .month:
                startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            case .all:
                startDate = Date(timeIntervalSince1970: 0)
            }
            
            let results = DatabaseManager.shared.getTextInputs(startDate: startDate, endDate: endDate)
            
            DispatchQueue.main.async {
                self.textInputs = results
                self.isLoading = false
                print("Loaded \(results.count) text inputs")
            }
        }
    }
    
    private func searchTextInputs() {
        guard !searchText.isEmpty else {
            loadTextInputs()
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = DatabaseManager.shared.searchTextInputs(query: searchText)
            
            DispatchQueue.main.async {
                self.textInputs = results
                self.isLoading = false
                print("Found \(results.count) text inputs matching '\(searchText)'")
            }
        }
    }
    
    private func deleteTextInput(id: Int64) {
        DatabaseManager.shared.deleteTextInput(id: id)
        
        textInputs.removeAll { $0.id == id }
        
        selectedTextInput = nil
    }
}

struct TextInputRow: View {
    let textInput: TextInput
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(textInput.text)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            
            HStack {
                Text(textInput.appName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !textInput.windowTitle.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(textInput.windowTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: textInput.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let url = textInput.url, !url.isEmpty {
                Text(url)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// Commented out preview to avoid AppState initialization issue
/*
struct TextInputView_Previews: PreviewProvider {
    static var previews: some View {
        TextInputView()
            .environmentObject(AppState())
    }
}
*/ 