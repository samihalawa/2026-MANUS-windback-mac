#!/usr/bin/env swift

import Foundation

// MARK: - Main Script

print("🔧 AutoRecall Database and Storage Repair Tool")
print("==============================================")

// Get the Application Support directory
guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
    print("❌ Failed to access Application Support directory")
    exit(1)
}

let autoRecallDir = appSupportURL.appendingPathComponent("AutoRecall")
let databasePath = autoRecallDir.appendingPathComponent("autorecall.sqlite").path

print("📂 Application data directory: \(autoRecallDir.path)")

// Check if the directory exists
if !FileManager.default.fileExists(atPath: autoRecallDir.path) {
    print("⚠️ AutoRecall directory does not exist. Creating it...")
    do {
        try FileManager.default.createDirectory(at: autoRecallDir, withIntermediateDirectories: true)
        print("✅ Created AutoRecall directory")
    } catch {
        print("❌ Failed to create directory: \(error.localizedDescription)")
        exit(1)
    }
}

// Check database file
if FileManager.default.fileExists(atPath: databasePath) {
    print("✅ Database file exists at: \(databasePath)")
    
    // Create backup
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let backupPath = autoRecallDir.appendingPathComponent("autorecall_backup_\(dateFormatter.string(from: Date())).sqlite").path
    
    do {
        try FileManager.default.copyItem(atPath: databasePath, toPath: backupPath)
        print("✅ Created database backup at: \(backupPath)")
    } catch {
        print("⚠️ Failed to create backup: \(error.localizedDescription)")
    }
} else {
    print("⚠️ Database file not found at: \(databasePath)")
}

// Check required directories
let requiredDirs = [
    "Screenshots",
    "Videos",
    "Audio",
    "Clipboard",
    "Database",
    "Logs"
]

var createdDirs = 0
for dirName in requiredDirs {
    let dirPath = autoRecallDir.appendingPathComponent(dirName).path
    if !FileManager.default.fileExists(atPath: dirPath) {
        do {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: dirPath), withIntermediateDirectories: true)
            print("✅ Created missing directory: \(dirName)")
            createdDirs += 1
        } catch {
            print("❌ Failed to create directory \(dirName): \(error.localizedDescription)")
        }
    }
}

if createdDirs == 0 {
    print("✅ All required directories exist")
}

// Clean up temporary files
let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
do {
    let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("AutoRecall") }
    
    if tempFiles.isEmpty {
        print("✅ No temporary files to clean up")
    } else {
        var removedCount = 0
        for file in tempFiles {
            do {
                try FileManager.default.removeItem(at: file)
                removedCount += 1
            } catch {
                print("⚠️ Failed to remove temp file \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        print("🧹 Removed \(removedCount) temporary files")
    }
} catch {
    print("⚠️ Failed to check temporary directory: \(error.localizedDescription)")
}

// Set permissions
for dirName in requiredDirs {
    let dirPath = autoRecallDir.appendingPathComponent(dirName).path
    if FileManager.default.fileExists(atPath: dirPath) {
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dirPath)
            print("✅ Fixed permissions for: \(dirName)")
        } catch {
            print("⚠️ Failed to set permissions for \(dirName): \(error.localizedDescription)")
        }
    }
}

print("==============================================")
print("✅ Repair process completed")
print("You can now restart AutoRecall to use the repaired database and storage.")
print("If you continue to experience issues, please reinstall the application.") 