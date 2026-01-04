//
//  ExecutionService.swift
//  composer
//
//  Service for executing flow nodes via the Composer backend API
//

import Foundation

/// Service for executing nodes via the Composer backend
actor ExecutionService {
    static let shared = ExecutionService()

    private let baseURL = URL(string: "https://composer.design/api/execute")!

    private init() {}

    /// Execute a node and return a stream of events
    func execute(
        nodeType: String,
        inputs: [String: String],
        provider: String,
        model: String
    ) -> AsyncThrowingStream<ExecutionEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Get API key for provider
                    guard let apiKey = await APIKeyStorage.shared.getKey(for: provider) else {
                        let errorMsg = "No API key configured for \(provider). Add it in Settings."
                        await MainActor.run {
                            DebugLogger.shared.log(.error, errorMsg)
                        }
                        continuation.yield(.error(errorMsg))
                        continuation.finish()
                        return
                    }

                    // Build request body
                    let body: [String: Any] = [
                        "type": nodeType,
                        "inputs": inputs,
                        "provider": provider,
                        "model": model,
                        "apiKeys": [
                            provider: apiKey
                        ]
                    ]

                    let jsonData = try JSONSerialization.data(withJSONObject: body)

                    // Log API request (redacting keys)
                    await MainActor.run {
                        DebugLogger.shared.logAPIRequest(url: self.baseURL, method: "POST", body: body)
                    }

                    // Create request with timeout
                    var request = URLRequest(url: baseURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = jsonData
                    request.timeoutInterval = 120 // 2 minute timeout for LLM responses

                    // Execute request with streaming
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.yield(.error("Invalid response"))
                        continuation.finish()
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        let errorMsg = "API error: HTTP \(httpResponse.statusCode)"
                        await MainActor.run {
                            DebugLogger.shared.log(.error, errorMsg)
                        }
                        continuation.yield(.error(errorMsg))
                        continuation.finish()
                        return
                    }

                    // Check content type to determine parsing strategy
                    // - NDJSON: Each line is a JSON object like {"type": "text", "content": "..."}
                    // - Plain text: Vercel AI SDK toTextStreamResponse() format, raw text chunks
                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
                    let isNDJSON = contentType.contains("ndjson") || contentType.contains("json")

                    // Log API response
                    await MainActor.run {
                        DebugLogger.shared.logAPIResponse(statusCode: httpResponse.statusCode, contentType: contentType)
                    }

                    if isNDJSON {
                        // Parse NDJSON stream (used by image generation, Google thinking, etc.)
                        for try await line in bytes.lines {
                            if let event = NDJSONParser.parse(line: line) {
                                continuation.yield(event)

                                if case .done = event {
                                    break
                                }

                                if case .error = event {
                                    break
                                }
                            }
                        }
                    } else {
                        // Plain text stream (text-generation default)
                        var allText = ""
                        for try await line in bytes.lines {
                            allText += line + "\n"
                        }
                        if !allText.isEmpty {
                            let trimmedText = allText.trimmingCharacters(in: .whitespacesAndNewlines)
                            continuation.yield(.text(trimmedText))
                            // Log final text output
                            await MainActor.run {
                                let preview = String(trimmedText.prefix(200))
                                DebugLogger.shared.logAPIEvent(".text(\"\(preview)\(trimmedText.count > 200 ? "..." : "")\")")
                            }
                        }
                        continuation.yield(.done)
                        await MainActor.run {
                            DebugLogger.shared.logAPIEvent(".done")
                        }
                    }

                    continuation.finish()
                } catch {
                    // Log error
                    await MainActor.run {
                        DebugLogger.shared.logError(error, context: "API request failed")
                    }
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }
}
