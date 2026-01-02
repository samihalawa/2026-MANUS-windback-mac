import Foundation
import AppKit

/// Simple test script for TextInputManager
/// Run with: swift run AutoRecall-TextInputTest
struct TextInputTester {
    static func runTests() {
        print("=== TextInput Test Script ===")

        // Initialize database and text input manager
        let databaseManager = DatabaseManager.shared
        let textInputManager = TextInputManager.shared

        // Ensure the text inputs table exists
        databaseManager.createTextInputsTable()

        // Test 1: Simulate a few text inputs
        print("\nTest 1: Simulating text inputs...")

        let testInputs = [
            (text: "user@example.com", app: "Safari", window: "Login Page - example.com", url: "https://example.com/login", isUsername: true),
            (text: "This is a search query", app: "Google Chrome", window: "Google Search", url: "https://google.com", isUsername: false),
            (text: "Meeting notes about the project timeline", app: "Notes", window: "Project Notes", url: nil, isUsername: false),
            (text: "johndoe", app: "Twitter", window: "Twitter - Sign In", url: "https://twitter.com/login", isUsername: true)
        ]

        for (index, input) in testInputs.enumerated() {
            print("  Simulating input \(index + 1): '\(input.text)' in \(input.app)")
            
            textInputManager.simulateTextInput(
                text: input.text,
                appName: input.app,
                windowTitle: input.window,
                url: input.url
            )
            
            // Small delay to ensure database operations complete
            Thread.sleep(forTimeInterval: 0.1)
        }

        print("  Text inputs simulated")

        // Test 2: Query recent text inputs
        print("\nTest 2: Retrieving recent text inputs...")
        let recentInputs = databaseManager.getRecentTextInputs(limit: 10)

        print("  Found \(recentInputs.count) recent text inputs:")
        for (index, input) in recentInputs.enumerated() {
            print("  \(index + 1). \"\(input.text)\" - \(input.appName) at \(input.formattedDate)")
        }

        // Test 3: Search for specific text
        print("\nTest 3: Searching for text inputs...")
        let searchTerm = "user"
        print("  Searching for: '\(searchTerm)'")

        let searchResults = databaseManager.searchTextInputs(query: searchTerm)
        print("  Found \(searchResults.count) matching results:")
        for (index, result) in searchResults.enumerated() {
            print("  \(index + 1). \"\(result.text)\" - \(result.appName)")
        }

        // Test 4: Get text inputs near a time
        print("\nTest 4: Finding text inputs in a time range...")

        let timeRange: TimeInterval = 60 * 60 * 24 // 24 hours
        let timeResults = databaseManager.getTextInputs(
            startDate: Date().addingTimeInterval(-timeRange),
            endDate: Date()
        )

        print("  Found \(timeResults.count) text inputs in the last 24 hours")

        // Test 5: Test username detection
        print("\nTest 5: Finding username entries...")
        let usernameResults = databaseManager.getTextInputs().filter { $0.isUsername }
        print("  Found \(usernameResults.count) username entries:")
        for (index, username) in usernameResults.enumerated() {
            print("  \(index + 1). \"\(username.text)\" on \(username.appName)")
        }

        print("\n=== Text Input Tests Completed ===")
    }
} 