//
//  DebugLogger.swift
//  composer
//
//  Centralized debug logging that writes to a file Claude can read (macOS only)
//

import Foundation

/// Log categories for structured debug output
enum LogCategory: String {
    case flowState = "FLOW_STATE"
    case execution = "EXECUTION"
    case api = "API"
    case error = "ERROR"
    case event = "EVENT"
}

#if os(macOS)

/// Centralized debug logger that writes to ~/Library/Logs/Composer/debug.log
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    private let logURL: URL
    private let maxFileSize: Int = 100_000 // 100KB max
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        // Set up log file path - use app's container for sandbox compatibility
        let logsDir: URL
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            logsDir = appSupport.appendingPathComponent("Composer/Logs")
        } else {
            logsDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/Composer")
        }

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        } catch {
            print("DebugLogger: Failed to create log directory: \(error)")
        }

        logURL = logsDir.appendingPathComponent("debug.log")

        // Set up date formatter
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Write initial header
        writeHeader()

        // Log the log file location for debugging
        print("DebugLogger: Writing to \(logURL.path)")
    }

    // MARK: - Public API

    /// The path to the debug log file
    var logFilePath: String { logURL.path }

    /// Log a message with a category
    func log(_ category: LogCategory, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(category.rawValue)] \(timestamp)\n\(message)\n\n"
        appendToLog(entry)
    }

    /// Log the complete flow state (nodes, edges, execution data)
    func logFlowState(_ flow: Flow) {
        var lines: [String] = []
        lines.append("Flow: \(flow.name)")
        lines.append("Nodes: \(flow.nodes.count), Edges: \(flow.edges.count)")
        lines.append("")

        // Edges
        lines.append("EDGES:")
        if flow.edges.isEmpty {
            lines.append("  (no edges)")
        } else {
            for edge in flow.edges {
                let sourceInfo = edge.sourceNode.map { "\($0.label) [\($0.nodeType.rawValue)]" } ?? "nil"
                let targetInfo = edge.targetNode.map { "\($0.label) [\($0.nodeType.rawValue)]" } ?? "nil"
                lines.append("  Edge: \(edge.sourceHandle) → \(edge.targetHandle) (\(edge.dataType.rawValue))")
                lines.append("    sourceNode: \(sourceInfo)")
                lines.append("    targetNode: \(targetInfo)")
            }
        }
        lines.append("")

        // Nodes
        lines.append("NODES:")
        for node in flow.nodes {
            lines.append("  \(node.label) [\(node.nodeType.rawValue)]")
            lines.append("    incomingEdges: \(node.incomingEdges.count), outgoingEdges: \(node.outgoingEdges.count)")

            // Node-specific data
            switch node.nodeType {
            case .textInput:
                if let data = node.decodeData(TextInputData.self) {
                    let preview = String(data.text.prefix(100))
                    lines.append("    text: \"\(preview)\(data.text.count > 100 ? "..." : "")\"")
                }

            case .textGeneration:
                if let data = node.decodeData(TextGenerationData.self) {
                    lines.append("    provider: \(data.provider), model: \(data.model)")
                    lines.append("    status: \(data.executionStatus.rawValue)")
                    if !data.executionOutput.isEmpty {
                        let preview = String(data.executionOutput.prefix(200))
                        lines.append("    output: \"\(preview)\(data.executionOutput.count > 200 ? "..." : "")\"")
                    }
                    if let error = data.executionError {
                        lines.append("    error: \(error)")
                    }
                }

            case .previewOutput:
                for edge in node.incomingEdges {
                    if let src = edge.sourceNode {
                        lines.append("    ← from: \(src.label)")
                    }
                }
            }
        }

        log(.flowState, lines.joined(separator: "\n"))
    }

    /// Log execution start
    func logExecutionStart(flowName: String, nodeCount: Int) {
        log(.execution, "Execution started: \(flowName) (\(nodeCount) nodes)")
    }

    /// Log execution completion
    func logExecutionComplete(flowName: String, duration: TimeInterval, nodeResults: [String]) {
        var lines = [
            "Execution completed: \(flowName)",
            "Duration: \(String(format: "%.2f", duration))s",
            "Results:"
        ]
        lines.append(contentsOf: nodeResults.map { "  - \($0)" })
        log(.execution, lines.joined(separator: "\n"))
    }

    /// Log a node execution result
    func logNodeExecution(label: String, type: String, status: String, output: String?, error: String?, duration: TimeInterval?) {
        var lines = ["\(label) [\(type)]: \(status)"]
        if let duration {
            lines[0] += " (\(String(format: "%.2f", duration))s)"
        }
        if let output, !output.isEmpty {
            let preview = String(output.prefix(500))
            lines.append("  output: \"\(preview)\(output.count > 500 ? "..." : "")\"")
        }
        if let error {
            lines.append("  error: \(error)")
        }
        log(.execution, lines.joined(separator: "\n"))
    }

    /// Log API request (with redacted keys)
    func logAPIRequest(url: URL, method: String, body: [String: Any]) {
        var sanitizedBody = body
        sanitizedBody["apiKeys"] = "[REDACTED]"

        let bodyString: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: sanitizedBody, options: [.sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            bodyString = jsonString
        } else {
            bodyString = String(describing: sanitizedBody)
        }

        log(.api, "\(method) \(url.absoluteString)\nBody: \(bodyString)")
    }

    /// Log API response
    func logAPIResponse(statusCode: Int, contentType: String) {
        log(.api, "Response: HTTP \(statusCode), Content-Type: \(contentType)")
    }

    /// Log API streaming event
    func logAPIEvent(_ event: String) {
        log(.api, "Event: \(event)")
    }

    /// Log an error with context
    func logError(_ error: Error, context: String) {
        log(.error, "\(context): \(error.localizedDescription)")
    }

    /// Log a general event
    func logEvent(_ message: String) {
        log(.event, message)
    }

    // MARK: - Private

    private func writeHeader() {
        let header = """
        === COMPOSER DEBUG LOG ===
        App started: \(dateFormatter.string(from: Date()))
        Log file: \(logURL.path)

        """

        // Truncate and write header
        try? header.write(to: logURL, atomically: true, encoding: .utf8)
    }

    private func appendToLog(_ entry: String) {
        // Check file size and truncate if needed
        if let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
           let size = attributes[.size] as? Int,
           size > maxFileSize {
            truncateLog()
        }

        // Append entry
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        } else {
            // File doesn't exist, create with header + entry
            writeHeader()
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                try? handle.close()
            }
        }
    }

    private func truncateLog() {
        // Keep only the last 50KB when truncating
        guard let data = try? Data(contentsOf: logURL),
              data.count > maxFileSize / 2 else { return }

        let keepSize = maxFileSize / 2
        let startIndex = data.count - keepSize
        let truncatedData = data.suffix(from: startIndex)

        // Find first newline to start at a clean line
        if let newlineIndex = truncatedData.firstIndex(of: UInt8(ascii: "\n")) {
            let cleanData = truncatedData.suffix(from: truncatedData.index(after: newlineIndex))

            let header = """
            === COMPOSER DEBUG LOG ===
            Log truncated: \(dateFormatter.string(from: Date()))
            (older entries removed to save space)

            """

            var finalData = header.data(using: .utf8) ?? Data()
            finalData.append(cleanData)
            try? finalData.write(to: logURL)
        }
    }
}

#else

/// No-op debug logger for iOS (debugging only supported on macOS)
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    var logFilePath: String { "" }

    func log(_ category: LogCategory, _ message: String) {}
    func logFlowState(_ flow: Flow) {}
    func logExecutionStart(flowName: String, nodeCount: Int) {}
    func logExecutionComplete(flowName: String, duration: TimeInterval, nodeResults: [String]) {}
    func logNodeExecution(label: String, type: String, status: String, output: String?, error: String?, duration: TimeInterval?) {}
    func logAPIRequest(url: URL, method: String, body: [String: Any]) {}
    func logAPIResponse(statusCode: Int, contentType: String) {}
    func logAPIEvent(_ event: String) {}
    func logError(_ error: Error, context: String) {}
    func logEvent(_ message: String) {}
}

#endif
