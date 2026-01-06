//
//  ExecutionTypes.swift
//  composer
//
//  Types for node execution: inputs, outputs, values, and context
//

import Foundation
import SwiftData

/// Execution status for processing nodes
enum ExecutionStatus: String, Codable, Sendable {
    case idle
    case running
    case success
    case error
}

/// Errors that can occur during node execution
enum NodeExecutionError: Error, LocalizedError {
    /// API returned an error message
    case apiError(String)
    /// Network or other execution failure
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API error: \(message)"
        case .executionFailed(let message):
            return message
        }
    }
}

/// Values that can flow between nodes
enum NodeValue: Sendable {
    case string(String)
    case image(Data)
    case audio(Data)
    case pulse

    /// Get string value if this is a string type
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    /// Get image data if this is an image type
    var imageData: Data? {
        if case .image(let data) = self {
            return data
        }
        return nil
    }

    /// Get audio data if this is an audio type
    var audioData: Data? {
        if case .audio(let data) = self {
            return data
        }
        return nil
    }

    /// The port data type this value corresponds to
    var portDataType: PortDataType {
        switch self {
        case .string: return .string
        case .image: return .image
        case .audio: return .audio
        case .pulse: return .pulse
        }
    }
}

/// Input values for node execution, keyed by port ID
struct NodeInputs: Sendable {
    private var values: [String: NodeValue] = [:]

    /// Get value for a port ID
    subscript(portId: String) -> NodeValue? {
        get { values[portId] }
        set { values[portId] = newValue }
    }

    /// Get string value for a port ID
    func string(for portId: String) -> String? {
        values[portId]?.stringValue
    }

    /// Get image data for a port ID
    func imageData(for portId: String) -> Data? {
        values[portId]?.imageData
    }

    /// Get audio data for a port ID
    func audioData(for portId: String) -> Data? {
        values[portId]?.audioData
    }

    /// Check if a port has any value
    func hasValue(for portId: String) -> Bool {
        values[portId] != nil
    }

    /// All port IDs that have values
    var portIds: [String] {
        Array(values.keys)
    }
}

/// Output values from node execution, keyed by port ID
struct NodeOutputs: Sendable {
    private var values: [String: NodeValue] = [:]

    init() {}

    /// Get value for a port ID
    subscript(portId: String) -> NodeValue? {
        get { values[portId] }
        set { values[portId] = newValue }
    }

    /// All port IDs that have values
    var portIds: [String] {
        Array(values.keys)
    }

    /// Check if this output is empty
    var isEmpty: Bool {
        values.isEmpty
    }

    /// Get all values as a dictionary
    var allValues: [String: NodeValue] {
        values
    }
}

/// Context provided to nodes during execution
///
/// Provides access to ModelContext for fetching fresh SwiftData objects,
/// following the iOS SwiftData patterns documented in `.claude/rules/swiftdata-view-model.md`.
@MainActor
struct ExecutionContext: Sendable {
    /// ModelContext for fetching fresh objects
    let modelContext: ModelContext

    /// Accumulated outputs from upstream nodes (keyed by node ID, then port ID)
    private var nodeOutputs: [UUID: NodeOutputs]

    init(modelContext: ModelContext, nodeOutputs: [UUID: NodeOutputs] = [:]) {
        self.modelContext = modelContext
        self.nodeOutputs = nodeOutputs
    }

    /// Get output from an upstream node
    func output(from nodeId: UUID, portId: String) -> NodeValue? {
        nodeOutputs[nodeId]?[portId]
    }

    /// Get all outputs for a node
    func outputs(for nodeId: UUID) -> NodeOutputs? {
        nodeOutputs[nodeId]
    }

    /// Create a new context with additional node outputs
    func adding(outputs: NodeOutputs, for nodeId: UUID) -> ExecutionContext {
        var newOutputs = nodeOutputs
        newOutputs[nodeId] = outputs
        return ExecutionContext(modelContext: modelContext, nodeOutputs: newOutputs)
    }
}
