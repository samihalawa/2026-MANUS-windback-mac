//
//  RAGService.swift
//  AutoRecall
//
//  Retrieval-Augmented Generation service
//  Orchestrates multi-cascade context retrieval for AI chat
//  Adapted from rem/2025-MANUS-AutoRecall Reflex Arc protocol
//

import Foundation
import SwiftUI
import os

// MARK: - RAG Context Structures

/// Container for multi-tiered context results
struct RAGContext {
    let immediateContext: [FrameContext]      // Cascade 1: Last 4 hours
    let historicalContext: [FrameContext]     // Cascade 2: Last 7 days
    let thematicContext: [FrameContext]       // Cascade 3: All history
    let relevanceScores: [String: Double]      // Frame relevance scores
    let totalTokensEstimate: Int              // Token usage estimate

    var isEmpty: Bool {
        immediateContext.isEmpty && historicalContext.isEmpty && thematicContext.isEmpty
    }
}

/// Individual frame context with metadata
struct FrameContext: Identifiable {
    let id: String
    let text: String                          // OCR text content
    let timestamp: Date                       // When frame was captured
    let appName: String?                      // Application name
    let windowTitle: String?                  // Window title
    let isDirectMatch: Bool                   // True if from direct search
    let cascade: ContextCascade               // Which cascade tier

    enum ContextCascade: String {
        case immediate = "4h"
        case historical = "7d"
        case thematic = "all"

        var emoji: String {
            switch self {
            case .immediate: return "🔴"
            case .historical: return "🟡"
            case .thematic: return "🔵"
            }
        }
    }
}

// MARK: - RAG Service

class RAGService: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.autorecall",
        category: "RAGService"
    )

    @Published var isRetrieving: Bool = false
    @Published var lastContextSize: Int = 0

    private let storage = StorageManager.shared

    // Configuration - token limits per cascade
    private let maxTokensPerCascade: [FrameContext.ContextCascade: Int] = [
        .immediate: 3000,    // Cascade 1: Most detail
        .historical: 1500,   // Cascade 2: Moderate detail
        .thematic: 800       // Cascade 3: Summary only
    ]

    // MARK: - Core RAG Functions

    /// Build multi-cascade context for a query using Reflex Arc protocol
    func buildContextForQuery(_ query: String) async -> RAGContext {
        await MainActor.run { isRetrieving = true }

        logger.info("Building RAG context for query: '\(query)'")

        let allScreenshots = storage.getAllScreenshots()
        let now = Date()
        let fourHoursAgo = now.addingTimeInterval(-4 * 60 * 60)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)

        // Cascade 1: Immediate context (last 4 hours)
        let immediateScreenshots = allScreenshots.filter { $0.timestamp >= fourHoursAgo }
        let immediate = buildCascadeContext(
            from: immediateScreenshots,
            query: query,
            cascade: .immediate,
            limit: 10
        )

        // Cascade 2: Historical context (last 7 days, excluding immediate)
        let historicalScreenshots = allScreenshots.filter {
            $0.timestamp >= sevenDaysAgo && $0.timestamp < fourHoursAgo
        }
        let historical = buildCascadeContext(
            from: historicalScreenshots,
            query: query,
            cascade: .historical,
            limit: 5
        )

        // Cascade 3: Thematic context (all history, excluding recent)
        let thematicScreenshots = allScreenshots.filter { $0.timestamp < sevenDaysAgo }
        let thematic = buildCascadeContext(
            from: thematicScreenshots,
            query: query,
            cascade: .thematic,
            limit: 3
        )

        // Calculate relevance scores
        var scores: [String: Double] = [:]
        for frame in immediate { scores[frame.id] = 1.0 }
        for frame in historical { scores[frame.id] = 0.6 }
        for frame in thematic { scores[frame.id] = 0.3 }

        // Estimate token usage
        let tokenEstimate = estimateTokens(
            immediate: immediate,
            historical: historical,
            thematic: thematic
        )

        let context = RAGContext(
            immediateContext: immediate,
            historicalContext: historical,
            thematicContext: thematic,
            relevanceScores: scores,
            totalTokensEstimate: tokenEstimate
        )

        await MainActor.run {
            isRetrieving = false
            lastContextSize = tokenEstimate
        }

        logger.info("RAG context built: \(immediate.count) immediate, \(historical.count) historical, \(thematic.count) thematic (~\(tokenEstimate) tokens)")

        return context
    }

    /// Format RAG context for LLM consumption
    func formatContextForLLM(_ context: RAGContext) -> String {
        guard !context.isEmpty else {
            return "No screen history context available."
        }

        var output = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        // Cascade 1: Immediate
        if !context.immediateContext.isEmpty {
            output += "🔴 IMMEDIATE CONTEXT (Last 4 hours):\n"
            for frame in context.immediateContext {
                output += formatFrame(frame, dateFormatter: dateFormatter)
            }
            output += "\n"
        }

        // Cascade 2: Historical
        if !context.historicalContext.isEmpty {
            output += "🟡 HISTORICAL CONTEXT (Last 7 days):\n"
            for frame in context.historicalContext {
                output += formatFrame(frame, dateFormatter: dateFormatter)
            }
            output += "\n"
        }

        // Cascade 3: Thematic
        if !context.thematicContext.isEmpty {
            output += "🔵 THEMATIC CONTEXT (Long-term):\n"
            for frame in context.thematicContext {
                output += formatFrame(frame, dateFormatter: dateFormatter)
            }
        }

        return output
    }

    // MARK: - Private Helpers

    private func buildCascadeContext(
        from screenshots: [Screenshot],
        query: String,
        cascade: FrameContext.ContextCascade,
        limit: Int
    ) -> [FrameContext] {
        let lowercasedQuery = query.lowercased()
        let queryTerms = lowercasedQuery.split(separator: " ").map { String($0) }

        // Score and filter screenshots
        var scoredScreenshots: [(Screenshot, Double)] = []

        for screenshot in screenshots {
            var score = 0.0
            let ocrLower = screenshot.ocrText.lowercased()
            let titleLower = screenshot.windowTitle.lowercased()
            let appLower = screenshot.appName.lowercased()

            // Check for query term matches
            for term in queryTerms where term.count > 2 {
                if ocrLower.contains(term) { score += 2.0 }
                if titleLower.contains(term) { score += 1.5 }
                if appLower.contains(term) { score += 1.0 }
            }

            // Boost recent items slightly
            let age = Date().timeIntervalSince(screenshot.timestamp)
            let recencyBonus = max(0, 1.0 - (age / (7 * 24 * 60 * 60)))
            score += recencyBonus * 0.5

            if score > 0 || query.isEmpty {
                scoredScreenshots.append((screenshot, score))
            }
        }

        // Sort by score and take top results
        let topScreenshots = scoredScreenshots
            .sorted { $0.1 > $1.1 }
            .prefix(limit)

        return topScreenshots.map { screenshot, _ in
            FrameContext(
                id: screenshot.id,
                text: truncateText(screenshot.ocrText, maxTokens: maxTokensPerCascade[cascade] ?? 1000),
                timestamp: screenshot.timestamp,
                appName: screenshot.appName,
                windowTitle: screenshot.windowTitle,
                isDirectMatch: !query.isEmpty,
                cascade: cascade
            )
        }
    }

    private func formatFrame(_ frame: FrameContext, dateFormatter: DateFormatter) -> String {
        var output = "[\(dateFormatter.string(from: frame.timestamp))]"
        if let app = frame.appName {
            output += " \(app)"
        }
        if let title = frame.windowTitle, !title.isEmpty {
            output += " - \(title)"
        }
        output += "\n"

        // Add truncated text
        let textPreview = frame.text.prefix(200)
        if !textPreview.isEmpty {
            output += "  \"\(textPreview)\(frame.text.count > 200 ? "..." : "")\"\n"
        }

        return output
    }

    private func truncateText(_ text: String, maxTokens: Int) -> String {
        // Rough estimate: 1 token ≈ 4 characters
        let maxChars = maxTokens * 4
        if text.count <= maxChars {
            return text
        }
        return String(text.prefix(maxChars)) + "..."
    }

    private func estimateTokens(
        immediate: [FrameContext],
        historical: [FrameContext],
        thematic: [FrameContext]
    ) -> Int {
        let allText = (immediate + historical + thematic).map { $0.text }.joined()
        // Rough estimate: 1 token ≈ 4 characters
        return allText.count / 4
    }
}
