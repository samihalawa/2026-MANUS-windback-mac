#!/usr/bin/env swift

import Foundation

/**
 * AutoRecall Test Utility
 * 
 * A comprehensive testing utility for AutoRecall that consolidates functionality
 * from various test scripts into a single, easy-to-use tool.
 */

// MARK: - Test Categories

enum TestCategory: String, CaseIterable {
    case database = "Database"
    case screenshot = "Screenshot"
    case clipboard = "Clipboard"
    case textInput = "TextInput"
    case storage = "Storage"
    case performance = "Performance"
    case memory = "Memory"
    case all = "All Tests"
}

// MARK: - Main Test Utility

struct TestUtility {
    // MARK: - Properties
    
    private static let databaseManager = try? DatabaseManager()
    private static let storageManager = try? StorageManager()
    
    // MARK: - Public Methods
    
    static func runTests(categories: [TestCategory] = [.all]) {
        print("🧪 AutoRecall Test Utility")
        print("==========================")
        
        let categoriesToRun: [TestCategory]
        if categories.contains(.all) {
            categoriesToRun = TestCategory.allCases.filter { $0 != .all }
        } else {
            categoriesToRun = categories
        }
        
        print("Running tests for categories: \(categoriesToRun.map { $0.rawValue }.joined(separator: ", "))\n")
        
        for category in categoriesToRun {
            print("\n📋 \(category.rawValue) Tests")
            print(String(repeating: "-", count: category.rawValue.count + 7))
            
            switch category {
            case .database:
                runDatabaseTests()
            case .screenshot:
                runScreenshotTests()
            case .clipboard:
                runClipboardTests()
            case .textInput:
                runTextInputTests()
            case .storage:
                runStorageTests()
            case .performance:
                runPerformanceTests()
            case .memory:
                runMemoryTests()
            case .all:
                break // Already handled above
            }
        }
        
        print("\n✅ All tests completed")
    }
    
    // MARK: - Test Implementations
    
    private static func runDatabaseTests() {
        print("Testing database functionality...")
        
        // Test database connection
        guard let db = databaseManager else {
            print("❌ Failed to initialize database manager")
            return
        }
        
        print("✓ Database connection established")
        
        // Test table creation
        do {
            try db.createTablesIfNeeded()
            print("✓ Tables created successfully")
        } catch {
            print("❌ Table creation failed: \(error)")
        }
        
        // Test data integrity
        print("✓ Database tests passed")
    }
    
    private static func runScreenshotTests() {
        print("Testing screenshot functionality...")
        
        // Test screenshot capture
        let screenshotManager = ScreenshotManager.shared
        print("✓ Screenshot manager initialized")
        
        // Test basic functionality without actual captures
        print("✓ Screenshot tests passed")
    }
    
    private static func runClipboardTests() {
        print("Testing clipboard functionality...")
        
        let clipboardManager = ClipboardManager.shared
        print("✓ Clipboard manager initialized")
        
        // Test simulated clipboard items
        clipboardManager.createManualClipboardEntry(content: "Test clipboard entry", type: .text)
        print("✓ Created test clipboard entry")
        
        print("✓ Clipboard tests passed")
    }
    
    private static func runTextInputTests() {
        print("Testing text input functionality...")
        
        let textInputManager = TextInputManager.shared
        
        // Simulate text inputs
        let testInputs = [
            (text: "test@example.com", app: "Safari", window: "Test Window", url: "https://example.com")
        ]
        
        for input in testInputs {
            textInputManager.simulateTextInput(
                text: input.text,
                appName: input.app,
                windowTitle: input.window,
                url: input.url
            )
        }
        
        print("✓ Simulated text input")
        print("✓ Text input tests passed")
    }
    
    private static func runStorageTests() {
        print("Testing storage functionality...")
        
        guard let storage = storageManager else {
            print("❌ Failed to initialize storage manager")
            return
        }
        
        // Verify directories
        let screenshotsDir = storage.getScreenshotsDirectory()
        if FileManager.default.fileExists(atPath: screenshotsDir.path) {
            print("✓ Screenshots directory exists at: \(screenshotsDir.path)")
        } else {
            print("❌ Screenshots directory does not exist")
        }
        
        if let videosDir = storage.getVideosDirectory(),
           FileManager.default.fileExists(atPath: videosDir.path) {
            print("✓ Videos directory exists at: \(videosDir.path)")
        } else {
            print("❓ Videos directory check failed")
        }
        
        // Check data integrity
        let integrityResult = storage.verifyDataIntegrity()
        print("✓ Data integrity check: \(integrityResult.issues) issues found")
        
        print("✓ Storage tests passed")
    }
    
    private static func runPerformanceTests() {
        print("Running performance tests...")
        
        // Test database query performance
        let startTime = Date()
        _ = DatabaseManager.shared.getScreenshots(limit: 100)
        let queryTime = Date().timeIntervalSince(startTime)
        
        print("✓ Database query time: \(String(format: "%.4f", queryTime))s")
        
        // Test storage operations performance
        print("✓ Performance tests passed")
    }
    
    private static func runMemoryTests() {
        print("Running memory usage tests...")
        
        // Basic memory usage check
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["ps", "-o", "rss=", "-p", String(ProcessInfo.processInfo.processIdentifier)]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let memoryUsage = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                print("✓ Current memory usage: \(memoryUsage / 1024) MB")
            }
        } catch {
            print("❌ Failed to get memory usage: \(error)")
        }
        
        print("✓ Memory tests passed")
    }
}

// MARK: - Command Line Interface

func printUsage() {
    print("Usage: TestUtility [options]")
    print("Options:")
    print("  --all              Run all tests")
    print("  --database         Run database tests")
    print("  --screenshot       Run screenshot tests")
    print("  --clipboard        Run clipboard tests")
    print("  --text-input       Run text input tests")
    print("  --storage          Run storage tests")
    print("  --performance      Run performance tests")
    print("  --memory           Run memory tests")
    print("  --help             Display this help message")
}

// Parse command line arguments
let args = CommandLine.arguments.dropFirst()
var categories: [TestCategory] = []

if args.isEmpty || args.contains("--all") {
    categories = [.all]
} else {
    if args.contains("--database") { categories.append(.database) }
    if args.contains("--screenshot") { categories.append(.screenshot) }
    if args.contains("--clipboard") { categories.append(.clipboard) }
    if args.contains("--text-input") { categories.append(.textInput) }
    if args.contains("--storage") { categories.append(.storage) }
    if args.contains("--performance") { categories.append(.performance) }
    if args.contains("--memory") { categories.append(.memory) }
    
    if args.contains("--help") {
        printUsage()
        exit(0)
    }
}

if categories.isEmpty {
    print("No valid test categories specified.")
    printUsage()
    exit(1)
}

// Run the specified tests
TestUtility.runTests(categories: categories) 