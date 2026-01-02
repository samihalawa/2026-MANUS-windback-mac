//
//  GeminiService.swift
//  AutoRecall
//
//  AI Chat Service using Google Gemini API
//  Adapted from rem/2025-MANUS-AutoRecall
//

import Foundation
import SwiftUI
import os

// MARK: - Message Models
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    var isLoading: Bool = false

    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Gemini API Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig?
    let systemInstruction: GeminiContent?

    struct GeminiContent: Codable {
        let role: String?
        let parts: [Part]

        struct Part: Codable {
            let text: String?
            let inlineData: InlineData?

            struct InlineData: Codable {
                let mimeType: String
                let data: String // base64 encoded
            }
        }
    }

    struct GenerationConfig: Codable {
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let maxOutputTokens: Int?
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]?
    let error: GeminiError?

    struct Candidate: Codable {
        let content: Content?
        let finishReason: String?

        struct Content: Codable {
            let parts: [Part]?
            let role: String?

            struct Part: Codable {
                let text: String?
            }
        }
    }

    struct GeminiError: Codable {
        let code: Int?
        let message: String?
        let status: String?
    }
}

// MARK: - Gemini Service
class GeminiService: ObservableObject {
    static let shared = GeminiService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.autorecall",
        category: "GeminiService"
    )

    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var ragService = RAGService()

    @AppStorage("geminiAPIKey") private var storedApiKey = ""

    private var apiKey: String {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"], !key.isEmpty {
            return key
        }
        if !storedApiKey.isEmpty {
            return storedApiKey
        }
        return ""
    }

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    // System prompt with RAG awareness and anti-hallucination safeguards
    private let systemPrompt = """
    You are an AI assistant integrated into WindBack, a privacy-focused screen recording app with Retrieval-Augmented Generation (RAG) capabilities.

    CRITICAL RULES - YOU MUST FOLLOW THESE:
    1. You can ONLY analyze images/screenshots that are explicitly provided to you
    2. You can ONLY discuss OCR text that is explicitly provided to you
    3. NEVER make up, invent, or hallucinate any screen activity, applications, websites, or content
    4. NEVER pretend to have access to screen history unless actual data is provided
    5. If no image or OCR text is provided, clearly state that you need the user to share their screen data
    6. Be honest about your limitations

    RAG CONTEXT AWARENESS:
    When screen history context IS provided via multi-cascade retrieval:
    - Cascade 1 (immediate/4h) has the highest relevance and most detail
    - Cascade 2 (historical/7d) provides entity correlation from recent days
    - Cascade 3 (thematic/all) offers long-term memory patterns
    - ONLY reference information actually present in the provided cascades
    - Cite which cascade tier you're drawing information from

    When an image IS provided:
    - Describe ONLY what you can actually see in the provided image
    - Extract text that is actually visible
    - Identify applications or websites that are actually shown

    Be helpful, honest, and transparent about what you can and cannot do.
    """

    private init() {}

    // MARK: - Public Methods

    func sendMessage(_ userMessage: String, withImage: Data? = nil, useRAG: Bool = true) async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            messages.append(ChatMessage(role: .user, content: userMessage, timestamp: Date()))
        }

        // Build RAG context if enabled
        var ragContext: RAGContext?
        if useRAG {
            ragContext = await ragService.buildContextForQuery(userMessage)
        }

        do {
            let response = try await callGeminiAPI(
                userMessage: userMessage,
                image: withImage,
                ragContext: ragContext
            )

            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: response, timestamp: Date()))
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
                logger.error("Gemini API error: \(error.localizedDescription)")
            }
        }
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func callGeminiAPI(userMessage: String, image: Data?, ragContext: RAGContext?) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        // Build content parts
        var parts: [GeminiRequest.GeminiContent.Part] = []

        // Add RAG context if available
        if let context = ragContext, !context.isEmpty {
            let contextText = ragService.formatContextForLLM(context)
            parts.append(GeminiRequest.GeminiContent.Part(text: "SCREEN HISTORY CONTEXT:\n\(contextText)", inlineData: nil))
        }

        // Add image if provided
        if let imageData = image {
            let base64Image = imageData.base64EncodedString()
            parts.append(GeminiRequest.GeminiContent.Part(
                text: nil,
                inlineData: GeminiRequest.GeminiContent.Part.InlineData(mimeType: "image/png", data: base64Image)
            ))
        }

        // Add user message
        parts.append(GeminiRequest.GeminiContent.Part(text: userMessage, inlineData: nil))

        // Build request
        let request = GeminiRequest(
            contents: [GeminiRequest.GeminiContent(role: "user", parts: parts)],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: 0.7,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 2048
            ),
            systemInstruction: GeminiRequest.GeminiContent(
                role: nil,
                parts: [GeminiRequest.GeminiContent.Part(text: systemPrompt, inlineData: nil)]
            )
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let error = errorResponse.error {
                throw GeminiError.apiError(error.message ?? "Unknown error")
            }
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw GeminiError.emptyResponse
        }

        return text
    }
}

// MARK: - Gemini Errors
enum GeminiError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key not configured. Set GEMINI_API_KEY environment variable or add in preferences."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .emptyResponse:
            return "Empty response from API"
        }
    }
}
