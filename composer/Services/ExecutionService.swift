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
                        continuation.yield(.error("No API key configured for \(provider). Add it in Settings."))
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
                        continuation.yield(.error("API error: HTTP \(httpResponse.statusCode)"))
                        continuation.finish()
                        return
                    }

                    // Parse NDJSON stream
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

                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }
}
