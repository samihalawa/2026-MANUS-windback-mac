import SwiftUI

struct CustomContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var isGlobalSearchActive = false
    @State private var sidebarWidth: CGFloat = 70
    @State private var isExpanded: Bool = false
    @State private var isStatusExpanded: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            NavigationSplitView {
                // Sidebar
                VStack(spacing: 0) {
                    // ... (logo, divider) ...
                    
                    // Global search if sidebar is expanded
                    if isExpanded {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            // ...
                            TextField("Search everything...", text: $searchText)
                                // ...
                                .onSubmit {
                                    // Use appState.selectedTab
                                    appState.selectedTab = .search 
                                    NotificationCenter.default.post(
                                        name: Notification.Name("SetGlobalSearch"),
                                        object: searchText
                                    )
                                }
                            // ... (clear button) ...
                        }
                        // ... (padding, background) ...
                    }
                    
                    // Tab buttons with modern design
                    VStack(spacing: 4) {
                        // Use TabIdentifier.allCases directly
                        ForEach(TabIdentifier.allCases, id: \.self) { tab in
                            // Use appState.selectedTab for selection state
                            Button(action: { withAnimation { appState.selectedTab = tab } }) {
                                HStack(spacing: 12) {
                                    Image(systemName: tab.icon)
                                        // ...
                                        // Use appState.selectedTab for foreground style
                                        .foregroundStyle(appState.selectedTab == tab ? tab.color : .secondary)
                                        // ...
                                    
                                    if isExpanded {
                                        Text(tab.title)
                                            // ...
                                            // Use appState.selectedTab for foreground color
                                            .foregroundColor(appState.selectedTab == tab ? tab.color : .primary)
                                        
                                        Spacer()
                                    }
                                }
                                // ...
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        // Use appState.selectedTab for background fill
                                        .fill(appState.selectedTab == tab ? 
                                            tab.color.opacity(0.15) : 
                                            Color.clear)
                                )
                            }
                           // ... (button style, padding, help) ...
                        }
                    }
                    
                    Spacer()
                    
                    // ... (Recording status section) ...
                    
                    Divider()
                    
                    // Bottom buttons section (settings, etc)
                    VStack(spacing: 0) {
                        Button(action: {
                            // Navigate to Settings tab
                            appState.selectedTab = .settings
                        }) {
                            // ... (HStack content) ...
                        }
                        // ... (button style, padding, help) ...
                        
                        Button(action: {
                           // Navigate to About tab
                           appState.selectedTab = .about
                        }) {
                           // ... (HStack content) ...
                        }
                        // ... (button style, padding, help) ...
                    }
                }
                .frame(width: sidebarWidth)
                // ... (background, overlay) ...
            } detail: {
                ZStack {
                    // Background color based on tab with gradient effect
                    LinearGradient(
                        // Use appState.selectedTab for color
                        colors: [
                            appState.selectedTab.color.opacity(0.05),
                            appState.selectedTab.color.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Dynamic content based on selected tab with smooth transitions
                    Group {
                        // Use appState.selectedTab for switch
                        switch appState.selectedTab {
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
                        // Add cases for Settings and About
                        case .settings:
                             PreferencesView()
                                .transition(.opacity)
                        case .about:
                             AboutView()
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Global search overlay - Use local state
                    if isGlobalSearchActive {
                        GlobalSearchView(isActive: $isGlobalSearchActive)
                            .frame(width: 600, height: 400)
                            .transition(.move(edge: .top))
                    }
                }
            }
            // ... (Toolbar modifications if necessary, depends on AppState fix) ...
        }
        // ... (onReceive handlers) ...
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchTab"))) { notification in
             if let tab = notification.object as? TabIdentifier { // Use TabIdentifier
                 withAnimation {
                     appState.selectedTab = tab // Update appState
                 }
             }
         }
         .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ActivateGlobalSearch"))) { _ in
             withAnimation {
                 isGlobalSearchActive = true // Update local state for overlay
             }
         }
         .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SetGlobalSearch"))) { notification in
             if let query = notification.object as? String {
                 searchText = query // Update local state
                 appState.selectedTab = .search // Update appState tab
             }
         }
    }
    // ... (recordingControlsView and helper methods) ...
} 