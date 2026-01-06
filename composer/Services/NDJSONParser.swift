//
//  NDJSONParser.swift
//  composer
//
//  Parser for NDJSON (Newline Delimited JSON) streaming responses
//

import Foundation

/// Events emitted during flow execution
enum ExecutionEvent: Sendable {
    case text(String)
    case reasoning(String)
    case usage(promptTokens: Int, completionTokens: Int)
    case error(String)
    case done
    case image(Data, String)              // (imageData, mimeType)
    case partialImage(Data, Int, String)  // (imageData, index, mimeType)
}

/// Parser for NDJSON streaming responses
struct NDJSONParser: Sendable {
    /// Parse a single NDJSON line into an ExecutionEvent
    static nonisolated func parse(line: String) -> ExecutionEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let data = trimmed.data(using: .utf8) else { return nil }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            guard let type = json["type"] as? String else {
                return nil
            }

            switch type {
            case "text":
                guard let content = json["content"] as? String else { return nil }
                return .text(content)

            case "reasoning":
                guard let content = json["content"] as? String else { return nil }
                return .reasoning(content)

            case "usage":
                let promptTokens = json["promptTokens"] as? Int ?? 0
                let completionTokens = json["completionTokens"] as? Int ?? 0
                return .usage(promptTokens: promptTokens, completionTokens: completionTokens)

            case "error":
                if let message = json["message"] as? String {
                    return .error(message)
                } else if let content = json["content"] as? String {
                    return .error(content)
                }
                return nil

            case "done":
                return .done

            case "image":
                guard let value = json["value"] as? String,
                      let mimeType = json["mimeType"] as? String,
                      let data = Data(base64Encoded: value) else { return nil }
                return .image(data, mimeType)

            case "partial":
                guard let value = json["value"] as? String,
                      let mimeType = json["mimeType"] as? String,
                      let index = json["index"] as? Int,
                      let data = Data(base64Encoded: value) else { return nil }
                return .partialImage(data, index, mimeType)

            default:
                return nil
            }
        } catch {
            return nil
        }
    }
}
