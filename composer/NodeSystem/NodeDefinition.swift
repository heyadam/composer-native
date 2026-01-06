//
//  NodeDefinition.swift
//  composer
//
//  Core protocol for self-contained node implementations
//

import SwiftUI

/// Protocol that defines a complete, self-contained node implementation.
///
/// Each node type implements this protocol to define its:
/// - Identity (type, display name, icon, category)
/// - Data storage (NodeData struct)
/// - Ports (input/output definitions)
/// - UI (content view)
/// - Execution behavior
/// - Output value access (for preview nodes to read data)
///
/// Nodes are registered in `NodeRegistry` which provides type-erased access.
protocol NodeDefinition {
    /// The NodeType enum case this definition corresponds to
    static var nodeType: NodeType { get }

    /// Codable data structure stored in FlowNode.dataJSON
    associatedtype NodeData: Codable

    /// Default data for newly created nodes
    static var defaultData: NodeData { get }

    // MARK: - Display

    /// Human-readable name shown in the UI
    static var displayName: String { get }

    /// SF Symbol icon name
    static var icon: String { get }

    /// Category for organization in node picker
    static var category: NodeCategory { get }

    // MARK: - Ports

    /// Input port definitions (stable IDs)
    static var inputPorts: [PortDefinition] { get }

    /// Output port definitions (stable IDs)
    static var outputPorts: [PortDefinition] { get }

    // MARK: - View

    /// The view type returned by makeContentView
    associatedtype ContentView: View

    /// Create the content view for this node
    /// - Parameters:
    ///   - node: The FlowNode model
    ///   - viewModel: Optional NodeViewModel for transient state
    ///   - state: Canvas state for coordinate transforms and selection
    ///   - connectionViewModel: For port connection gestures
    /// - Returns: The node's content view
    @MainActor
    static func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> ContentView

    // MARK: - Execution

    /// Whether this node performs async execution (vs pass-through)
    static var isExecutable: Bool { get }

    /// Execute this node
    /// - Parameters:
    ///   - node: The FlowNode being executed
    ///   - inputs: Input values from connected upstream nodes
    ///   - context: Execution context with ModelContext access
    /// - Returns: Output values keyed by port ID
    @MainActor
    static func execute(
        node: FlowNode,
        inputs: NodeInputs,
        context: ExecutionContext
    ) async throws -> NodeOutputs

    // MARK: - Output Access

    /// Get the current output value for a port
    ///
    /// Used by preview nodes to read connected data without knowing node types.
    /// Returns nil if the node has no output for the requested port.
    ///
    /// - Parameters:
    ///   - node: The source node to read from
    ///   - portId: The output port ID to read
    /// - Returns: The current value at that port, or nil
    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue?

    // MARK: - Execution Status

    /// Get the current execution status for an executable node
    ///
    /// Used by flow execution logging to report status uniformly across all
    /// executable node types without hardcoding specific NodeData types.
    ///
    /// - Parameter node: The node to get status from
    /// - Returns: The execution status, or nil for non-executable nodes
    @MainActor
    static func getExecutionStatus(node: FlowNode) -> ExecutionStatus?
}

// MARK: - Default Implementations

extension NodeDefinition {
    /// Default: nodes are not executable (pass-through)
    static var isExecutable: Bool { false }

    /// Default: no-op execution returns empty outputs
    @MainActor
    static func execute(
        node: FlowNode,
        inputs: NodeInputs,
        context: ExecutionContext
    ) async throws -> NodeOutputs {
        NodeOutputs()
    }

    /// Default: no output value
    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        nil
    }

    /// Default: no execution status (non-executable nodes)
    @MainActor
    static func getExecutionStatus(node: FlowNode) -> ExecutionStatus? {
        nil
    }
}
