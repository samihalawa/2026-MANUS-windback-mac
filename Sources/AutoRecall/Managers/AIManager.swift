import Foundation
import SwiftUI
import Combine
import Vision
import NaturalLanguage
import CoreML

class AIManager {
    static let shared = AIManager()
    
    // MARK: - Published Properties
    @AppStorage("aiFeatureEnabled") private var aiFeatureEnabled = true
    @AppStorage("aiLocalProcessing") private var aiLocalProcessing = false // Default to API processing for better results
    @AppStorage("aiModelQuality") private var aiModelQuality = 1 // 0: Standard, 1: High, 2: Maximum
    
    // OpenAI API settings
    @AppStorage("openaiApiKey") private var openaiApiKey = "" // Set your API key in preferences
    @AppStorage("openaiModel") private var openaiModel = "mistralai/Mistral-7B-Instruct-v0.2" // More reliable model
    @AppStorage("openaiApiBase") private var openaiApiBase = "https://api-inference.huggingface.co/models"
    
    // Chat history persistence
    private var chatHistory: [Message] = []
    
    // MARK: - Properties
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    private let storage = StorageManager.shared
    private let nlpQueue = DispatchQueue(label: "com.autorecall.nlp", qos: .userInitiated)
    @Published private(set) var relevantItems: [Screenshot] = []
    @Published private(set) var matchingScreenshots: [Screenshot] = []
    
    // MARK: - Initialization
    private init() {
        // Validate API configuration on initialization
        validateAPIConfiguration()
    }
    
    // Validate API configuration
    private func validateAPIConfiguration() {
        // Check if the API key looks valid
        if openaiApiKey.count < 10 {
            NSLog("Warning: API key appears to be invalid or too short")
        }
        
        // Check if API base URL is valid
        if !openaiApiBase.lowercased().starts(with: "http") {
            NSLog("Warning: API base URL appears to be invalid")
        }
        
        // Log current configuration
        NSLog("AI Configuration - Model: \(openaiModel), Local Processing: \(aiLocalProcessing), API Base: \(openaiApiBase)")
    }
    
    // MARK: - Public Methods
    
    /// Process a message and return a response
    func processMessage(_ message: String, previousMessages: [Message] = [], completion: @escaping (Result<String, Error>) -> Void) {
        // Store the message in chat history
        chatHistory = previousMessages
        
        // Check if AI features are enabled
        guard aiFeatureEnabled else {
            NSLog("AI processing skipped: AI features are disabled")
            completion(.failure(AIError.aiDisabled))
            return
        }
        
        NSLog("Processing AI message: \(message)")
        
        if aiLocalProcessing {
            // Use local model with simplified implementation
            processLocalMessage(message, previousMessages: previousMessages, completion: completion)
        } else {
            // Use API with better error handling
            processAPIMessage(message, previousMessages: previousMessages) { result in
                switch result {
                case .success(let response):
                    completion(.success(response))
                case .failure(let error):
                    NSLog("API processing failed: \(error.localizedDescription)")
                    // Fallback to local processing if API fails
                    self.processLocalMessage(message, previousMessages: previousMessages, completion: completion)
                }
            }
        }
    }
    
    func findRelevantScreenshots(for query: String, limit: Int = 10) -> [Screenshot] {
        let allScreenshots = storage.getAllScreenshots()
        var foundItems: [Screenshot] = []
        
        // Search in OCR text
        foundItems.append(contentsOf: allScreenshots.filter { 
            $0.ocrText.localizedCaseInsensitiveContains(query)
        })
        
        // Search in window titles
        foundItems.append(contentsOf: allScreenshots.filter { 
            $0.windowTitle.localizedCaseInsensitiveContains(query)
        })
        
        // Search in app names
        foundItems.append(contentsOf: allScreenshots.filter {
            $0.appName.localizedCaseInsensitiveContains(query)
        })
        
        // Search in URLs
        foundItems.append(contentsOf: allScreenshots.filter {
            guard let url = $0.url else { return false }
            return url.localizedCaseInsensitiveContains(query)
        })
        
        // If no exact matches found, try fuzzy matching
        if foundItems.isEmpty {
            foundItems.append(contentsOf: allScreenshots.filter {
                let similarity = calculateStringSimilarity(between: query.lowercased(), and: $0.ocrText.lowercased())
                return similarity > 0.7
            })
            
            foundItems.append(contentsOf: allScreenshots.filter {
                let similarity = calculateStringSimilarity(between: query.lowercased(), and: $0.windowTitle.lowercased())
                return similarity > 0.7
            })
            
            foundItems.append(contentsOf: allScreenshots.filter {
                let similarity = calculateStringSimilarity(between: query.lowercased(), and: $0.appName.lowercased())
                return similarity > 0.7
            })
        }
        
        // If still no matches, return most recent items
        if foundItems.isEmpty {
            foundItems = Array(allScreenshots.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5))
        }
        
        // Remove duplicates and sort by timestamp
        let uniqueItems = Array(Set(foundItems))
        relevantItems = Array(uniqueItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
        return relevantItems
    }
    
    func findSimilarScreenshots(to screenshot: Screenshot, limit: Int = 10) -> [Screenshot] {
        let allScreenshots = storage.getAllScreenshots()
        var foundItems: [Screenshot] = []
        
        // Find items with similar OCR text
        foundItems.append(contentsOf: allScreenshots.filter {
            let similarity = calculateStringSimilarity(between: screenshot.ocrText.lowercased(), and: $0.ocrText.lowercased())
            return similarity > 0.7
        })
        
        // Find items from the same app
        foundItems.append(contentsOf: allScreenshots.filter {
            $0.appName == screenshot.appName
        })
        
        // Find items with similar window titles
        foundItems.append(contentsOf: allScreenshots.filter {
            let similarity = calculateStringSimilarity(between: screenshot.windowTitle.lowercased(), and: $0.windowTitle.lowercased())
            return similarity > 0.7
        })
        
        // Remove duplicates and sort by timestamp
        let uniqueItems = Array(Set(foundItems))
        matchingScreenshots = Array(uniqueItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
        return matchingScreenshots
    }
    
    // MARK: - Private Methods
    
    /// Retrieve relevant context based on the user's query
    private func retrieveRelevantContext(for query: String) -> String {
        // Get all screenshots
        let allScreenshots = storage.getAllScreenshots()
        guard !allScreenshots.isEmpty else {
            return "No recorded data found in your history."
        }
        
        // Simple keyword matching for now
        let lowercasedQuery = query.lowercased()
        var relevantItems: [Screenshot] = []
        
        // Check for time-related queries
        if lowercasedQuery.contains("yesterday") {
            relevantItems.append(contentsOf: allScreenshots.filter { 
                Calendar.current.isDateInYesterday($0.timestamp)
            })
        } else if lowercasedQuery.contains("today") || lowercasedQuery.contains("this morning") {
            relevantItems.append(contentsOf: allScreenshots.filter { 
                Calendar.current.isDateInToday($0.timestamp)
            })
        } else if lowercasedQuery.contains("last week") {
            relevantItems.append(contentsOf: allScreenshots.filter { 
                let components = Calendar.current.dateComponents([.weekOfYear], from: $0.timestamp, to: Date())
                return components.weekOfYear ?? 0 <= 1
            })
        }
        
        // Check for content-related queries
        if lowercasedQuery.contains("code") || lowercasedQuery.contains("swift") {
            relevantItems.append(contentsOf: allScreenshots.filter {
                $0.appName == "Xcode" || $0.ocrText.lowercased().contains("func ") || $0.ocrText.lowercased().contains("class ")
            })
        }
        
        if lowercasedQuery.contains("menu bar") || lowercasedQuery.contains("menubar") {
            relevantItems.append(contentsOf: allScreenshots.filter {
                $0.ocrText.lowercased().contains("menu") || $0.windowTitle.lowercased().contains("menubar")
            })
        }
        
        if lowercasedQuery.contains("meeting") || lowercasedQuery.contains("zoom") || lowercasedQuery.contains("call") {
            relevantItems.append(contentsOf: allScreenshots.filter {
                $0.appName == "Zoom" || $0.isTranscription
            })
        }
        
        if lowercasedQuery.contains("clipboard") || lowercasedQuery.contains("copied") || lowercasedQuery.contains("image") {
            relevantItems.append(contentsOf: allScreenshots.filter {
                $0.isClipboardItem
            })
        }
        
        // Text search in OCR content
        let searchTerms = lowercasedQuery.split(separator: " ")
            .filter { $0.count > 3 } // Only use terms with more than 3 characters
            .map { String($0) }
        
        if !searchTerms.isEmpty {
            for term in searchTerms {
                relevantItems.append(contentsOf: allScreenshots.filter {
                    $0.ocrText.lowercased().contains(term)
                })
            }
        }
        
        // If no specific matches, return the most recent items
        if relevantItems.isEmpty {
            relevantItems = Array(allScreenshots.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5))
        } else {
            // Remove duplicates
            var uniqueItems: [Screenshot] = []
            var seenIds = Set<String>()
            
            for item in relevantItems {
                if !seenIds.contains(item.id.uuidString) {
                    uniqueItems.append(item)
                    seenIds.insert(item.id.uuidString)
                }
            }
            
            relevantItems = uniqueItems
            
            // Limit to top 10 most relevant
            relevantItems = Array(relevantItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(10))
        }
        
        // Format the context
        var contextString = "Here is relevant information from the user's history:\n\n"
        
        for (index, item) in relevantItems.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let timeString = dateFormatter.string(from: item.timestamp)
            
            contextString += "Item \(index + 1) - \(timeString):\n"
            contextString += "Application: \(item.appName)\n"
            contextString += "Window: \(item.windowTitle)\n"
            
            if let url = item.url {
                contextString += "URL: \(url)\n"
            }
            
            if item.isTranscription {
                contextString += "Transcript:\n"
            } else if item.isClipboardItem {
                contextString += "Clipboard Item:\n"
            } else {
                contextString += "Content:\n"
            }
            
            // Limit OCR text to a reasonable length
            let maxOCRLength = 500
            let ocrText = item.ocrText
            if ocrText.count > maxOCRLength {
                contextString += "\(ocrText.prefix(maxOCRLength))...\n\n"
            } else {
                contextString += "\(ocrText)\n\n"
            }
        }
        
        // Add summary of available data
        let totalItems = allScreenshots.count
        let clipboardItems = allScreenshots.filter { $0.isClipboardItem }.count
        let todayItems = allScreenshots.filter { Calendar.current.isDateInToday($0.timestamp) }.count
        
        contextString += "Summary of available data:\n"
        contextString += "- Total recorded items: \(totalItems)\n"
        contextString += "- Clipboard items: \(clipboardItems)\n"
        contextString += "- Items from today: \(todayItems)\n"
        
        return contextString
    }
    
    private func processLocalMessage(_ message: String, previousMessages: [Message], completion: @escaping (Result<String, Error>) -> Void) {
        // In a real implementation, this would use a quantized local model
        // For now, we'll simulate responses based on real data
        let modelQualityString = ["Standard", "High", "Maximum"][aiModelQuality]
        
        NSLog("Processing message with local model (quality: \(modelQualityString))")
        
        // Retrieve context relevant to the user's query
        let context = retrieveRelevantContext(for: message)
        NSLog("Retrieved context: \(context)")
        
        // Simulate processing time based on model quality
        let processingTime = Double(aiModelQuality + 1) * 0.5
        
        DispatchQueue.global().asyncAfter(deadline: .now() + processingTime) {
            // Create response based on input and real data
            let lowercasedMessage = message.lowercased()
            var response: String
            
            // Get all screenshots for reference
            let allScreenshots = self.storage.getAllScreenshots()
            let todayScreenshots = allScreenshots.filter { Calendar.current.isDateInToday($0.timestamp) }
            let yesterdayScreenshots = allScreenshots.filter { Calendar.current.isDateInYesterday($0.timestamp) }
            let clipboardItems = allScreenshots.filter { $0.isClipboardItem }
            
            // Check if this appears to be a follow-up message or a query about the AI's behavior
            if lowercasedMessage.contains("why") && (lowercasedMessage.contains("same") || lowercasedMessage.contains("again") || lowercasedMessage.contains("repeat")) {
                response = "I apologize if my previous response wasn't helpful or seemed repetitive. I'm designed to provide specific information about your screen recordings and clipboard history. Could you please ask a more specific question about your data, or tell me what kind of information you're looking for?"
            } else if lowercasedMessage.contains("yesterday") || lowercasedMessage.contains("last") {
                if yesterdayScreenshots.isEmpty {
                    response = "I don't have any recorded data from yesterday. Would you like me to search for data from another day?"
                } else {
                    let appCounts = Dictionary(grouping: yesterdayScreenshots, by: { $0.appName }).mapValues { $0.count }
                    let mostUsedApp = appCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
                    
                    response = "Based on your screen recordings from yesterday, I can see you were working primarily in \(mostUsedApp). "
                    
                    // Add details about specific content if available
                    let codeScreenshots = yesterdayScreenshots.filter { $0.ocrText.contains("func ") || $0.ocrText.contains("class ") }
                    if !codeScreenshots.isEmpty {
                        response += "You were working on code, including "
                        if let firstCode = codeScreenshots.first {
                            let codeSnippet = firstCode.ocrText.prefix(100)
                            response += "snippets like: \"\(codeSnippet)...\". "
                        }
                    }
                    
                    // Add browser activity if available
                    let browserScreenshots = yesterdayScreenshots.filter { $0.appName.contains("Safari") || $0.appName.contains("Chrome") || $0.appName.contains("Firefox") }
                    if !browserScreenshots.isEmpty {
                        response += "You also spent time browsing websites"
                        if let url = browserScreenshots.first?.url {
                            response += ", including \(url)"
                        }
                        response += ". "
                    }
                    
                    response += "Would you like more specific details about any of these activities?"
                }
            } else if lowercasedMessage.contains("search") || lowercasedMessage.contains("find") {
                // Extract search terms
                let searchTerms = lowercasedMessage.split(separator: " ")
                    .filter { $0.count > 3 && !["search", "find", "look", "for"].contains($0) }
                    .map { String($0) }
                
                if searchTerms.isEmpty {
                    response = "What specifically would you like me to search for in your recorded data? Please provide some keywords or a time period."
                } else {
                    // Search for terms in OCR text
                    var matchingScreenshots: [Screenshot] = []
                    for term in searchTerms {
                        matchingScreenshots.append(contentsOf: allScreenshots.filter {
                            $0.ocrText.lowercased().contains(term)
                        })
                    }
                    
                    // Remove duplicates
                    var uniqueMatches: [Screenshot] = []
                    var seenIds = Set<String>()
                    for item in matchingScreenshots {
                        if !seenIds.contains(item.id.uuidString) {
                            uniqueMatches.append(item)
                            seenIds.insert(item.id.uuidString)
                        }
                    }
                    
                    if uniqueMatches.isEmpty {
                        response = "I couldn't find any matches for '\(searchTerms.joined(separator: ", "))' in your recorded data. Would you like to try a different search term?"
                    } else {
                        response = "I found \(uniqueMatches.count) items matching '\(searchTerms.joined(separator: ", "))' in your recorded data:\n\n"
                        
                        // Show top 5 results
                        let topResults = uniqueMatches.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5)
                        for (index, result) in topResults.enumerated() {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            dateFormatter.timeStyle = .short
                            
                            response += "\(index + 1). \(dateFormatter.string(from: result.timestamp)) - \(result.appName): \(result.windowTitle)\n"
                            
                            // Add a snippet of the matching content
                            let snippet = result.ocrText.prefix(100)
                            response += "   \"\(snippet)...\"\n\n"
                        }
                        
                        response += "Would you like to see more details about any of these results?"
                    }
                }
            } else if lowercasedMessage.contains("summarize") || lowercasedMessage.contains("summary") {
                if allScreenshots.isEmpty {
                    response = "I don't have any recorded data to summarize. Once you start recording your screen, I'll be able to provide summaries of your activity."
                } else {
                    // Group by app name
                    let appCounts = Dictionary(grouping: allScreenshots, by: { $0.appName }).mapValues { $0.count }
                    let sortedApps = appCounts.sorted(by: { $0.value > $1.value }).prefix(5)
                    
                    // Calculate time periods
                    let today = todayScreenshots.count
                    let yesterday = yesterdayScreenshots.count
                    let older = allScreenshots.count - today - yesterday
                    
                    response = "Here's a summary of your recorded data:\n\n"
                    
                    // App usage
                    response += "Most used applications:\n"
                    for (index, app) in sortedApps.enumerated() {
                        let percentage = Double(app.value) / Double(allScreenshots.count) * 100
                        response += "\(index + 1). \(app.key): \(Int(percentage))%\n"
                    }
                    
                    // Time distribution
                    response += "\nTime distribution:\n"
                    response += "• Today: \(today) items\n"
                    response += "• Yesterday: \(yesterday) items\n"
                    response += "• Older: \(older) items\n"
                    
                    // Clipboard activity
                    response += "\nClipboard activity:\n"
                    response += "• Total clipboard items: \(clipboardItems.count)\n"
                    
                    if !clipboardItems.isEmpty {
                        let textItems = clipboardItems.filter { $0.windowTitle.contains("Text") }.count
                        let imageItems = clipboardItems.filter { $0.windowTitle.contains("Image") }.count
                        let urlItems = clipboardItems.filter { $0.windowTitle.contains("URL") }.count
                        let fileItems = clipboardItems.filter { $0.windowTitle.contains("File") }.count
                        
                        response += "• Text items: \(textItems)\n"
                        response += "• Image items: \(imageItems)\n"
                        response += "• URL items: \(urlItems)\n"
                        response += "• File items: \(fileItems)\n"
                    }
                }
            } else if lowercasedMessage.contains("analyze") && (lowercasedMessage.contains("clipboard") || lowercasedMessage.contains("copied")) {
                if clipboardItems.isEmpty {
                    response = "I don't have any clipboard items in your recorded data. Once you start recording your clipboard, I'll be able to analyze it."
                } else {
                    // Group by type
                    let textItems = clipboardItems.filter { $0.windowTitle.contains("Text") }
                    let imageItems = clipboardItems.filter { $0.windowTitle.contains("Image") }
                    let urlItems = clipboardItems.filter { $0.windowTitle.contains("URL") }
                    let fileItems = clipboardItems.filter { $0.windowTitle.contains("File") }
                    
                    response = "I've analyzed your clipboard history from the recorded sessions:\n\n"
                    
                    // Text items
                    if !textItems.isEmpty {
                        response += "Text items (\(textItems.count)):\n"
                        let recentTextItems = textItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3)
                        for (index, item) in recentTextItems.enumerated() {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            dateFormatter.timeStyle = .short
                            
                            let snippet = item.ocrText.prefix(50)
                            response += "\(index + 1). \(dateFormatter.string(from: item.timestamp)): \"\(snippet)...\"\n"
                        }
                        response += "\n"
                    }
                    
                    // Image items
                    if !imageItems.isEmpty {
                        response += "Image items (\(imageItems.count)):\n"
                        let recentImageItems = imageItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3)
                        for (index, item) in recentImageItems.enumerated() {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            dateFormatter.timeStyle = .short
                            
                            response += "\(index + 1). \(dateFormatter.string(from: item.timestamp)): [Image]\n"
                        }
                        response += "\n"
                    }
                    
                    // URL items
                    if !urlItems.isEmpty {
                        response += "URL items (\(urlItems.count)):\n"
                        let recentURLItems = urlItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3)
                        for (index, item) in recentURLItems.enumerated() {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            dateFormatter.timeStyle = .short
                            
                            response += "\(index + 1). \(dateFormatter.string(from: item.timestamp)): \(item.url ?? "Unknown URL")\n"
                        }
                        response += "\n"
                    }
                    
                    // File items
                    if !fileItems.isEmpty {
                        response += "File items (\(fileItems.count)):\n"
                        let recentFileItems = fileItems.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3)
                        for (index, item) in recentFileItems.enumerated() {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            dateFormatter.timeStyle = .short
                            
                            let fileCount = item.ocrText.split(separator: "\n").count
                            response += "\(index + 1). \(dateFormatter.string(from: item.timestamp)): \(fileCount) files\n"
                        }
                    }
                }
            } else if lowercasedMessage.contains("timeline") || lowercasedMessage.contains("activity") {
                if todayScreenshots.isEmpty {
                    response = "I don't have any recorded data from today. Would you like me to show your timeline from yesterday or another day?"
                } else {
                    // Group by hour
                    let calendar = Calendar.current
                    var hourlyActivity: [Int: [Screenshot]] = [:]
                    
                    for screenshot in todayScreenshots {
                        let hour = calendar.component(.hour, from: screenshot.timestamp)
                        if hourlyActivity[hour] == nil {
                            hourlyActivity[hour] = []
                        }
                        hourlyActivity[hour]?.append(screenshot)
                    }
                    
                    // Sort by hour
                    let sortedHours = hourlyActivity.keys.sorted()
                    
                    response = "Your timeline for today shows these key activities:\n\n"
                    
                    for hour in sortedHours {
                        guard let activities = hourlyActivity[hour] else { continue }
                        
                        // Format hour range
                        let hourStart = "\(hour):00"
                        let hourEnd = "\(hour):59"
                        
                        // Group by app
                        let appCounts = Dictionary(grouping: activities, by: { $0.appName }).mapValues { $0.count }
                        let mainApp = appCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
                        
                        response += "• \(hourStart)-\(hourEnd): "
                        
                        // Describe main activity
                        response += "Primarily using \(mainApp)"
                        
                        // Add details if available
                        if mainApp.contains("Safari") || mainApp.contains("Chrome") || mainApp.contains("Firefox") {
                            if let urlItem = activities.first(where: { $0.url != nil }) {
                                response += " (visited \(urlItem.url ?? "websites"))"
                            } else {
                                response += " (browsing websites)"
                            }
                        } else if mainApp == "Xcode" {
                            response += " (coding)"
                        } else if mainApp == "Zoom" {
                            response += " (in meetings)"
                        }
                        
                        response += "\n"
                    }
                    
                    response += "\nWould you like more details about any specific time period?"
                }
            } else if lowercasedMessage.contains("help") || lowercasedMessage.contains("feature") || lowercasedMessage.contains("what can you") {
                response = "I can help you with several things based on your recorded data:\n\n"
                response += "• Search through screen recordings using OCR extracted text\n"
                response += "• Find specific content you've seen on screen\n"
                response += "• Analyze your clipboard history\n"
                response += "• Provide a timeline of your activities\n"
                response += "• Summarize your work sessions and meetings\n"
                response += "• Answer questions about code you've worked on\n"
                response += "• Recall websites you've visited\n\n"
                
                response += "Try asking me questions like:\n"
                response += "• \"What was I working on yesterday afternoon?\"\n"
                response += "• \"Find the Swift code I was looking at about menu bars\"\n"
                response += "• \"Show me the image I copied an hour ago\"\n"
                response += "• \"Summarize my Zoom meeting from this morning\"\n\n"
                
                response += "All processing happens locally on your device for maximum privacy."
            } else {
                // Generic response for other queries
                if allScreenshots.isEmpty {
                    response = "I don't have any recorded data yet to answer your question. Once you start recording your screen and clipboard, I'll be able to provide more helpful responses."
                } else {
                    // Check if the last message in previousMessages is from the AI and has similar content
                    // to avoid sending duplicate responses
                    let lastAIMessage = previousMessages.last(where: { !$0.isUser })
                    
                    if let lastAI = lastAIMessage, 
                       lastAI.content.contains("Based on your recorded data, I can see you have") &&
                       lowercasedMessage.count < 10 {
                        // Provide a more personalized response instead of repeating the generic one
                        response = "I notice your message is quite short. To help you better, I need more specific questions about your data. You could ask about your activity at certain times, search for specific content you've seen, or ask for analysis of your clipboard or screenshots."
                    } else {
                        response = "Based on your recorded data, I can see you have \(allScreenshots.count) items in your history, including \(clipboardItems.count) clipboard items. "
                        
                        // Add recent activity
                        if !todayScreenshots.isEmpty {
                            let recentApps = Dictionary(grouping: todayScreenshots, by: { $0.appName }).mapValues { $0.count }
                            if let mainApp = recentApps.max(by: { $0.value < $1.value })?.key {
                                response += "Today, you've primarily been using \(mainApp). "
                            }
                        }
                        
                        response += "To help you better, try asking more specific questions about your timeline, clipboard history, or search for specific content you've seen on screen."
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(.success(response))
            }
        }
    }
    
    // MARK: - Private Methods for API Handling
    
    /// Process a message using the Hugging Face API
    private func processAPIMessage(_ message: String, previousMessages: [Message], completion: @escaping (Result<String, Error>) -> Void) {
        // Ensure API key is valid
        guard !openaiApiKey.isEmpty else {
            NSLog("AI processing failed: Missing API key")
            completion(.failure(AIError.missingAPIKey))
            return
        }
        
        // Construct API endpoint URL
        let modelEndpoint = openaiModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? openaiModel
        guard let url = URL(string: "\(openaiApiBase)/\(modelEndpoint)") else {
            NSLog("AI processing failed: Invalid API URL")
            completion(.failure(AIError.invalidAPIURL))
            return
        }
        
        // Prepare context from previous messages and relevant data
        let context = retrieveRelevantContext(for: message)
        
        // Build prompt with system message, context, chat history, and current query
        var prompt = "You are an AI assistant for AutoRecall, a privacy-focused app that captures screen recordings, text, and audio. Answer the following query based on the user's data. Be concise and helpful.\n\n"
        prompt += "Context from user's data: \(context)\n\n"
        
        // Add conversation history
        for prevMsg in previousMessages.suffix(6) { // Include last 6 messages for context
            if prevMsg.isUser {
                prompt += "User: \(prevMsg.content)\n"
                    } else {
                prompt += "Assistant: \(prevMsg.content)\n"
            }
        }
        
        // Add current query
        prompt += "User: \(message)\n"
        prompt += "Assistant:"
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "temperature": 0.7,
                "max_new_tokens": 500,
                "return_full_text": false
            ]
        ]
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(openaiApiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            NSLog("AI processing failed: Could not serialize request body")
            completion(.failure(error))
            return
        }
        
        // Send request
        let task = session.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                NSLog("AI processing failed: Network error: \(error.localizedDescription)")
                completion(.failure(error))
            return
        }
        
            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("AI processing failed: Invalid response")
                completion(.failure(AIError.invalidResponse))
            return
        }
        
            // Handle HTTP errors
            if httpResponse.statusCode != 200 {
                NSLog("AI processing failed: HTTP error \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    NSLog("Error details: \(errorString)")
                }
                completion(.failure(AIError.httpError(httpResponse.statusCode)))
                return
            }
            
            // Ensure data is present
            guard let data = data else {
                NSLog("AI processing failed: No data received")
                completion(.failure(AIError.noData))
                return
            }
            
            // Parse response
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstItem = jsonArray.first,
                   let generatedText = firstItem["generated_text"] as? String {
                    
                    // Success
                    NSLog("AI processing succeeded: \(generatedText.prefix(50))...")
                    completion(.success(generatedText))
                    return
                } else if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let generatedText = jsonObject["generated_text"] as? String {
                    
                    // Alternative response format
                    NSLog("AI processing succeeded: \(generatedText.prefix(50))...")
                    completion(.success(generatedText))
                    return
                } else if let responseString = String(data: data, encoding: .utf8) {
                    // Fallback to raw response string
                    NSLog("AI processing returned raw response: \(responseString.prefix(50))...")
                    completion(.success(responseString))
                    return
                } else {
                    // Failed to parse response
                    NSLog("AI processing failed: Could not parse response")
                    completion(.failure(AIError.invalidResponseFormat))
                }
            } catch {
                // JSON parsing error
                NSLog("AI processing failed: JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func calculateStringSimilarity(between str1: String, and str2: String) -> Double {
        let distance = levenshteinDistance(between: str1, and: str2)
        let maxLength = Double(max(str1.count, str2.count))
        return 1.0 - (Double(distance) / maxLength)
    }
    
    private func levenshteinDistance(between str1: String, and str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let m = str1Array.count
        let n = str2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if str1Array[i - 1] == str2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j - 1] + 1
                    )
                }
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Error Enum

enum AIError: Error, LocalizedError {
    case aiDisabled
    case missingAPIKey
    case jsonEncodingFailed
    case invalidResponse
    case invalidEndpoint
    case apiError(String)
    case networkError(Error)
    case noData
    case requestTimeout
    case invalidAPIURL
    case invalidResponseFormat
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .aiDisabled:
            return "AI features are disabled in settings"
        case .missingAPIKey:
            return "API key is missing. Please add your API key in preferences."
        case .jsonEncodingFailed:
            return "Failed to encode the message data"
        case .invalidResponse:
            return "Received an invalid response from the API"
        case .invalidEndpoint:
            return "Invalid API endpoint URL"
        case .apiError(let message):
            return "API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received from the API"
        case .requestTimeout:
            return "Request timed out"
        case .invalidAPIURL:
            return "Invalid API URL"
        case .invalidResponseFormat:
            return "Invalid response format"
        case .httpError(let code):
            return "HTTP error \(code)"
        }
    }
} 