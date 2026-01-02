import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let copyright = "© 2024 AutoRecall.ai. All Rights Reserved."
    private let websiteURL = "https://autorecall.ai"
    private let githubURL = "https://github.com/autorecall/autorecall"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("About AutoRecall")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            ScrollView {
                VStack(spacing: 40) {
                    // App logo and version info
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                        
                        VStack(spacing: 4) {
                            Text("AutoRecall")
                                .font(.largeTitle.bold())
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Description
                    VStack(spacing: 24) {
                        descriptionBlock(
                            title: "Your Second Brain",
                            icon: "brain.head.profile",
                            text: "AutoRecall automatically captures your digital activities, making them instantly searchable and accessible."
                        )
                        
                        descriptionBlock(
                            title: "Privacy-First Design",
                            icon: "lock.shield",
                            text: "All your data stays on your device. We use local AI processing, ensuring maximum privacy and security."
                        )
                        
                        descriptionBlock(
                            title: "AI-Powered Memory",
                            icon: "sparkles.rectangle.stack",
                            text: "Use natural language to ask about anything you've seen, done, or created on your Mac."
                        )
                    }
                    .padding(.horizontal)
                    
                    // Team
                    VStack(spacing: 16) {
                        Text("Key Features")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        featureList
                    }
                    .padding(.horizontal)
                    
                    // Links section
                    VStack(spacing: 12) {
                        Text("Resources")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        linksGrid
                    }
                    .padding(.horizontal)
                    
                    // Copyright
                    aboutView
                }
                .padding()
            }
        }
        .frame(width: 500, height: 640)
        .background(Color(.windowBackgroundColor))
    }
    
    private var featureList: some View {
        VStack(spacing: 12) {
            featureItem(icon: "camera.viewfinder", title: "Screen Recording", description: "Continuously record your screen activity")
            featureItem(icon: "text.viewfinder", title: "OCR Technology", description: "Extract and index all text from your screens")
            featureItem(icon: "clipboard", title: "Clipboard Monitoring", description: "Track and search your copy-paste history")
            featureItem(icon: "magnifyingglass", title: "Semantic Search", description: "Find anything with natural language search")
            featureItem(icon: "sparkles", title: "AI Assistance", description: "Get insights from your recorded data")
        }
    }
    
    private func featureItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var aboutView: some View {
        VStack(spacing: 12) {
            Text(copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("AutoRecall is a privacy-focused productivity tool.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Made with ❤️ by the AutoRecall team")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 4) {
                Button("Visit our website") {
                    if let url = URL(string: websiteURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                
                Button("Get Support") {
                    if let url = URL(string: "\(websiteURL)/support") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                
                Button("Privacy Policy") {
                    if let url = URL(string: "\(websiteURL)/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }
    
    private func descriptionBlock(title: String, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func teamMember(name: String, role: String, image: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: image)
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.blue.opacity(0.1)))
            
            Text(name)
                .font(.headline)
            
            Text(role)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var linksGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                resourceLink(title: "Website", icon: "globe", url: websiteURL)
                resourceLink(title: "Support", icon: "questionmark.circle", url: "\(websiteURL)/support")
            }
            
            GridRow {
                resourceLink(title: "Documentation", icon: "book.closed", url: "\(websiteURL)/docs")
                resourceLink(title: "Privacy", icon: "lock.shield", url: "\(websiteURL)/privacy")
            }
            
            GridRow {
                resourceLink(title: "FAQ", icon: "list.bullet", url: "\(websiteURL)/faq")
                resourceLink(title: "Contact", icon: "envelope", url: "\(websiteURL)/contact")
            }
        }
    }
    
    private func resourceLink(title: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
} 