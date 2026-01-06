//
//  NodeRegistry.swift
//  composer
//
//  Static registry for all node definitions with type-erased access
//

import SwiftUI

/// Type-erased wrapper for NodeDefinition conformers
///
/// This allows storing heterogeneous node definitions in a dictionary
/// while preserving access to their functionality.
struct AnyNodeDefinition: Sendable {
    let nodeType: NodeType
    let displayName: String
    let icon: String
    let category: NodeCategory
    let inputPorts: [PortDefinition]
    let outputPorts: [PortDefinition]
    let isExecutable: Bool

    private let _makeContentView: @MainActor @Sendable (FlowNode, NodeViewModel?, CanvasState, ConnectionViewModel?) -> AnyView
    private let _execute: @MainActor @Sendable (FlowNode, NodeInputs, ExecutionContext) async throws -> NodeOutputs
    private let _getOutputValue: @MainActor @Sendable (FlowNode, String) -> NodeValue?
    private let _getExecutionStatus: @MainActor @Sendable (FlowNode) -> ExecutionStatus?

    init<N: NodeDefinition>(_ type: N.Type) {
        self.nodeType = N.nodeType
        self.displayName = N.displayName
        self.icon = N.icon
        self.category = N.category
        self.inputPorts = N.inputPorts
        self.outputPorts = N.outputPorts
        self.isExecutable = N.isExecutable

        self._makeContentView = { node, viewModel, state, connectionViewModel in
            AnyView(N.makeContentView(node: node, viewModel: viewModel, state: state, connectionViewModel: connectionViewModel))
        }

        self._execute = { node, inputs, context in
            try await N.execute(node: node, inputs: inputs, context: context)
        }

        self._getOutputValue = { node, portId in
            N.getOutputValue(node: node, portId: portId)
        }

        self._getExecutionStatus = { node in
            N.getExecutionStatus(node: node)
        }
    }

    /// Create the content view for this node
    @MainActor
    func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> AnyView {
        _makeContentView(node, viewModel, state, connectionViewModel)
    }

    /// Execute this node
    @MainActor
    func execute(
        node: FlowNode,
        inputs: NodeInputs,
        context: ExecutionContext
    ) async throws -> NodeOutputs {
        try await _execute(node, inputs, context)
    }

    /// Get output value for a port
    @MainActor
    func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        _getOutputValue(node, portId)
    }

    /// Get execution status for an executable node
    @MainActor
    func getExecutionStatus(node: FlowNode) -> ExecutionStatus? {
        _getExecutionStatus(node)
    }
}

/// Central registry for all node definitions
///
/// Provides type-erased access to node functionality:
/// - Creating content views
/// - Executing nodes
/// - Reading output values
/// - Port compatibility checking
enum NodeRegistry {
    /// All registered node definitions, keyed by NodeType
    private static let definitions: [NodeType: AnyNodeDefinition] = {
        var registry: [NodeType: AnyNodeDefinition] = [:]
        register(TextInputNode.self, in: &registry)
        register(TextGenerationNode.self, in: &registry)
        register(PreviewOutputNode.self, in: &registry)
        register(ImageGenerationNode.self, in: &registry)
        return registry
    }()

    /// Register a node definition
    private static func register<N: NodeDefinition>(_ type: N.Type, in registry: inout [NodeType: AnyNodeDefinition]) {
        registry[N.nodeType] = AnyNodeDefinition(type)
    }

    // MARK: - Public API

    /// Get the definition for a node type
    static func definition(for type: NodeType) -> AnyNodeDefinition? {
        definitions[type]
    }

    /// Create a content view for a node
    @MainActor
    static func makeContentView(
        for node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> AnyView {
        guard let definition = definitions[node.nodeType] else {
            return AnyView(Text("Unknown node type: \(node.nodeType.rawValue)"))
        }
        return definition.makeContentView(node: node, viewModel: viewModel, state: state, connectionViewModel: connectionViewModel)
    }

    /// Execute a node
    @MainActor
    static func execute(
        node: FlowNode,
        inputs: NodeInputs,
        context: ExecutionContext
    ) async throws -> NodeOutputs {
        guard let definition = definitions[node.nodeType] else {
            return NodeOutputs()
        }
        return try await definition.execute(node: node, inputs: inputs, context: context)
    }

    /// Get output value from a node
    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        guard let definition = definitions[node.nodeType] else {
            return nil
        }
        return definition.getOutputValue(node: node, portId: portId)
    }

    /// Get input ports for a node type
    static func inputPorts(for type: NodeType) -> [PortDefinition] {
        definitions[type]?.inputPorts ?? []
    }

    /// Get output ports for a node type
    static func outputPorts(for type: NodeType) -> [PortDefinition] {
        definitions[type]?.outputPorts ?? []
    }

    /// Get display name for a node type
    static func displayName(for type: NodeType) -> String {
        definitions[type]?.displayName ?? type.rawValue
    }

    /// Get icon for a node type
    static func icon(for type: NodeType) -> String {
        definitions[type]?.icon ?? "questionmark.circle"
    }

    /// Get category for a node type
    static func category(for type: NodeType) -> NodeCategory {
        definitions[type]?.category ?? .input
    }

    /// Check if a node type is executable
    static func isExecutable(type: NodeType) -> Bool {
        definitions[type]?.isExecutable ?? false
    }

    /// Get execution status for a node
    ///
    /// Returns the current execution status for executable nodes,
    /// or nil for non-executable nodes.
    @MainActor
    static func getExecutionStatus(node: FlowNode) -> ExecutionStatus? {
        guard let definition = definitions[node.nodeType] else {
            return nil
        }
        return definition.getExecutionStatus(node: node)
    }

    /// Check if two ports can be connected
    ///
    /// Currently only allows same-type connections.
    /// Can be expanded for type coercion later.
    static func canConnect(sourceType: PortDataType, targetType: PortDataType) -> Bool {
        sourceType == targetType
    }

    /// Get all node types grouped by category
    static var nodesByCategory: [NodeCategory: [NodeType]] {
        var result: [NodeCategory: [NodeType]] = [:]
        for (type, definition) in definitions {
            result[definition.category, default: []].append(type)
        }
        return result
    }

    /// Get all registered node types
    static var allNodeTypes: [NodeType] {
        Array(definitions.keys)
    }
}
