//
//  FlowCanvasViewModel.swift
//  composer
//
//  Orchestrates canvas operations and manages transient state
//

import Foundation
import SwiftData
import SwiftUI

/// Connection point for edge creation
struct ConnectionPoint: Equatable, Sendable {
    let nodeId: UUID
    let portId: String
    let portType: PortDataType
    let isOutput: Bool
    var position: CGPoint

    init(nodeId: UUID, portId: String, portType: PortDataType, isOutput: Bool, position: CGPoint = .zero) {
        self.nodeId = nodeId
        self.portId = portId
        self.portType = portType
        self.isOutput = isOutput
        self.position = position
    }
}

/// Errors that can occur during flow operations
enum FlowError: Error, LocalizedError {
    case incompatiblePorts
    case circularConnection
    case nodeNotFound
    case edgeNotFound
    case invalidConnection

    var errorDescription: String? {
        switch self {
        case .incompatiblePorts: return "These ports are not compatible"
        case .circularConnection: return "This would create a circular connection"
        case .nodeNotFound: return "Node not found"
        case .edgeNotFound: return "Edge not found"
        case .invalidConnection: return "Invalid connection"
        }
    }
}

@MainActor @Observable
final class FlowCanvasViewModel {
    private let modelContext: ModelContext
    private(set) var flow: Flow

    // Transient state (not persisted during drag)
    var draggedNodePositions: [UUID: CGPoint] = [:]

    // Track which nodes have completed drags (position committed to SwiftData)
    private var committedDragNodeIds: Set<UUID> = []

    /// Whether any nodes are currently being dragged (not just have cached positions)
    var isDragging: Bool {
        draggedNodePositions.keys.contains { !committedDragNodeIds.contains($0) }
    }

    /// Whether flow execution is in progress
    private(set) var isExecuting: Bool = false

    /// Execution outputs for nodes (accumulated during execution)
    var nodeOutputs: [UUID: String] = [:]

    init(flow: Flow, context: ModelContext) {
        self.flow = flow
        self.modelContext = context
    }

    /// Undo support via SwiftData
    var undoManager: UndoManager? { modelContext.undoManager }

    // MARK: - Node Drag Operations

    /// Begin dragging a node - stores initial position
    func beginNodeDrag(_ nodeId: UUID, at position: CGPoint) {
        // Clear any previous committed state for this node
        committedDragNodeIds.remove(nodeId)
        draggedNodePositions[nodeId] = position
    }

    /// Update node position during drag (transient, no SwiftData write)
    func updateNodeDrag(_ nodeId: UUID, to position: CGPoint) {
        draggedNodePositions[nodeId] = position
    }

    /// End drag and commit position to SwiftData
    ///
    /// - Important: Pass the node object directly from the view, NOT by looking it up
    ///   via `flow.nodes.first(where:)`. On iOS, SwiftUI may recreate views with fresh
    ///   SwiftData objects, causing the view model's `flow.nodes` to become stale/empty
    ///   while the view's node references remain valid.
    ///
    /// - Parameter node: The node being dragged (passed directly from the view)
    func endNodeDrag(_ node: FlowNode) {
        let nodeId = node.id

        guard let finalPosition = draggedNodePositions[nodeId] else {
            draggedNodePositions.removeValue(forKey: nodeId)
            return
        }

        node.position = finalPosition
        flow.touch()

        DebugLogger.shared.logEvent("Node moved: \(node.label) to (\(Int(finalPosition.x)), \(Int(finalPosition.y)))")

        // Mark as committed but KEEP the position in draggedNodePositions
        // This prevents the view from reading stale SwiftData values
        // The position will be cleared when the next drag of this node starts
        committedDragNodeIds.insert(nodeId)
    }

    /// Get transient drag position for a node (nil if not being dragged)
    func transientPosition(for nodeId: UUID) -> CGPoint? {
        draggedNodePositions[nodeId]
    }

    /// Get current display position for a node (transient or persisted)
    /// Note: Prefer using transientPosition + node.position directly in views
    /// for proper SwiftData observation
    func displayPosition(for nodeId: UUID) -> CGPoint? {
        if let dragged = draggedNodePositions[nodeId] {
            return dragged
        }
        return flow.nodes.first(where: { $0.id == nodeId })?.position
    }

    // MARK: - Node Operations

    /// Add a new node to the flow
    func addNode(_ type: NodeType, at position: CGPoint) {
        let node = FlowNode(nodeType: type, position: position)
        node.flow = flow
        flow.nodes.append(node)
        flow.touch()
        modelContext.insert(node)

        DebugLogger.shared.logEvent("Node added: \(node.label) [\(type.rawValue)] at (\(Int(position.x)), \(Int(position.y)))")
    }

    /// Delete nodes by IDs
    ///
    /// - Important: Fetches nodes from ModelContext instead of flow.nodes to avoid
    ///   stale relationship arrays on iOS.
    func deleteNodes(_ ids: Set<UUID>) {
        // Fetch nodes fresh from context (flow.nodes may be stale on iOS)
        let predicate = #Predicate<FlowNode> { node in
            ids.contains(node.id)
        }
        guard let nodesToDelete = try? modelContext.fetch(FetchDescriptor(predicate: predicate)),
              !nodesToDelete.isEmpty else {
            print("⌨️ No nodes found to delete for IDs: \(ids)")
            return
        }

        let deletedLabels = nodesToDelete.map { $0.label }

        // Get fresh flow from first node
        guard let freshFlow = nodesToDelete.first?.flow else {
            print("⌨️ Could not get fresh flow reference")
            return
        }

        for node in nodesToDelete {
            // Edges will be cascade deleted due to relationship rules
            modelContext.delete(node)
        }
        freshFlow.touch()

        print("⌨️ Deleted nodes: \(deletedLabels.joined(separator: ", "))")
        DebugLogger.shared.logEvent("Nodes deleted: \(deletedLabels.joined(separator: ", "))")
    }

    /// Delete a single node
    func deleteNode(_ nodeId: UUID) {
        deleteNodes([nodeId])
    }

    // MARK: - Edge Operations

    /// Create an edge between two connection points
    ///
    /// - Important: Fetches nodes from ModelContext instead of flow.nodes to avoid
    ///   stale relationship arrays on iOS (same pattern as endNodeDrag).
    func createEdge(from source: ConnectionPoint, to target: ConnectionPoint) throws {
        // Validate: source must be output, target must be input
        guard source.isOutput && !target.isOutput else {
            throw FlowError.invalidConnection
        }

        // Validate port compatibility
        guard NodePortSchemas.canConnect(sourceType: source.portType, targetType: target.portType) else {
            throw FlowError.incompatiblePorts
        }

        // Find nodes from ModelContext (not flow.nodes which can be stale on iOS)
        let sourceId = source.nodeId
        let targetId = target.nodeId
        let sourcePredicate = #Predicate<FlowNode> { $0.id == sourceId }
        let targetPredicate = #Predicate<FlowNode> { $0.id == targetId }

        let sourceNodes = try? modelContext.fetch(FetchDescriptor(predicate: sourcePredicate))
        let targetNodes = try? modelContext.fetch(FetchDescriptor(predicate: targetPredicate))

        guard let sourceNode = sourceNodes?.first,
              let targetNode = targetNodes?.first else {
            throw FlowError.nodeNotFound
        }

        // Prevent self-connections
        guard source.nodeId != target.nodeId else {
            throw FlowError.circularConnection
        }

        // Check for circular connections (simple check - target can't be upstream of source)
        if wouldCreateCycle(source: sourceNode, target: targetNode) {
            throw FlowError.circularConnection
        }

        // Get fresh flow reference from the node (avoids stale ViewModel flow on iOS)
        guard let freshFlow = sourceNode.flow else {
            throw FlowError.nodeNotFound
        }

        // Create edge
        let edge = FlowEdge(
            sourceHandle: source.portId,
            targetHandle: target.portId,
            dataType: source.portType
        )

        // Use freshFlow for relationships so SwiftUI observes the change
        modelContext.insert(edge)
        edge.flow = freshFlow
        edge.sourceNode = sourceNode
        edge.targetNode = targetNode

        freshFlow.touch()

        print("🔌 Edge inserted into flow with \(freshFlow.edges.count) edges")
        DebugLogger.shared.logEvent("Edge created: \(sourceNode.label).\(source.portId) → \(targetNode.label).\(target.portId)")
    }

    /// Delete an edge by ID
    ///
    /// - Important: Fetches edge from ModelContext to avoid stale flow.edges on iOS.
    func deleteEdge(_ edgeId: UUID) {
        let predicate = #Predicate<FlowEdge> { $0.id == edgeId }
        guard let edges = try? modelContext.fetch(FetchDescriptor(predicate: predicate)),
              let edge = edges.first else { return }

        let sourceLabel = edge.sourceNode?.label ?? "?"
        let targetLabel = edge.targetNode?.label ?? "?"

        // Get fresh flow reference
        if let freshFlow = edge.flow {
            modelContext.delete(edge)
            freshFlow.touch()
        } else {
            modelContext.delete(edge)
        }

        DebugLogger.shared.logEvent("Edge deleted: \(sourceLabel) → \(targetLabel)")
    }

    /// Delete edges by IDs
    ///
    /// - Important: Fetches edges from ModelContext to avoid stale flow.edges on iOS.
    func deleteEdges(_ ids: Set<UUID>) {
        let predicate = #Predicate<FlowEdge> { edge in
            ids.contains(edge.id)
        }
        guard let edgesToDelete = try? modelContext.fetch(FetchDescriptor(predicate: predicate)),
              !edgesToDelete.isEmpty else { return }

        let deletedDescriptions = edgesToDelete.map { edge in
            let sourceLabel = edge.sourceNode?.label ?? "?"
            let targetLabel = edge.targetNode?.label ?? "?"
            return "\(sourceLabel) → \(targetLabel)"
        }

        // Get fresh flow from first edge
        let freshFlow = edgesToDelete.first?.flow

        for edge in edgesToDelete {
            modelContext.delete(edge)
        }
        freshFlow?.touch()

        if !deletedDescriptions.isEmpty {
            DebugLogger.shared.logEvent("Edges deleted: \(deletedDescriptions.joined(separator: ", "))")
        }
    }

    // MARK: - Cycle Detection

    /// Simple cycle detection - checks if target is upstream of source
    private func wouldCreateCycle(source: FlowNode, target: FlowNode) -> Bool {
        var visited: Set<UUID> = []
        var queue: [FlowNode] = [target]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current.id == source.id {
                return true
            }
            if visited.contains(current.id) {
                continue
            }
            visited.insert(current.id)

            // Get upstream nodes (nodes that feed into current)
            for edge in current.incomingEdges {
                if let upstream = edge.sourceNode {
                    queue.append(upstream)
                }
            }
        }

        return false
    }

    // MARK: - Flow Execution

    /// Execute the entire flow
    func executeFlow() async {
        guard !isExecuting else { return }

        let startTime = Date()
        isExecuting = true
        nodeOutputs.removeAll()

        DebugLogger.shared.logExecutionStart(flowName: flow.name, nodeCount: flow.nodes.count)

        // Topological sort nodes
        let sortedNodes = topologicalSort()

        // Track results for logging
        var nodeResults: [String] = []

        // Execute each node in order
        for node in sortedNodes {
            let nodeStart = Date()
            await executeNode(node)
            let nodeDuration = Date().timeIntervalSince(nodeStart)

            // Determine status for logging
            let status: String
            switch node.nodeType {
            case .textInput:
                status = "pass-through"
            case .textGeneration:
                let data = node.decodeData(TextGenerationData.self)
                status = data?.executionStatus.rawValue ?? "unknown"
            case .previewOutput:
                status = "pass-through"
            }

            nodeResults.append("\(node.label): \(status) (\(String(format: "%.2f", nodeDuration))s)")
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        DebugLogger.shared.logExecutionComplete(flowName: flow.name, duration: totalDuration, nodeResults: nodeResults)

        isExecuting = false
    }

    /// Topological sort of nodes based on edges
    private func topologicalSort() -> [FlowNode] {
        var result: [FlowNode] = []
        var visited: Set<UUID> = []
        var temp: Set<UUID> = []

        func visit(_ node: FlowNode) {
            if visited.contains(node.id) { return }
            if temp.contains(node.id) { return }  // Cycle detected, skip

            temp.insert(node.id)

            // Visit upstream nodes first
            for edge in node.incomingEdges {
                if let sourceNode = edge.sourceNode {
                    visit(sourceNode)
                }
            }

            temp.remove(node.id)
            visited.insert(node.id)
            result.append(node)
        }

        for node in flow.nodes {
            visit(node)
        }

        return result
    }

    /// Execute a single node
    private func executeNode(_ node: FlowNode) async {
        switch node.nodeType {
        case .textInput:
            // Text input nodes just output their stored text
            let data = node.decodeData(TextInputData.self) ?? TextInputData()
            nodeOutputs[node.id] = data.text

        case .textGeneration:
            await executeTextGeneration(node)

        case .previewOutput:
            // Preview nodes don't execute, they just display their input
            if let inputValue = getInputValue(for: node, portId: PortID.previewInputString) {
                nodeOutputs[node.id] = inputValue
            }
        }
    }

    /// Execute a text generation node
    private func executeTextGeneration(_ node: FlowNode) async {
        var data = node.decodeData(TextGenerationData.self) ?? TextGenerationData()

        // Set status to running
        data.executionStatus = .running
        data.executionOutput = ""
        data.executionError = nil
        node.encodeData(data)

        // Gather inputs from connected nodes
        let prompt = getInputValue(for: node, portId: PortID.textGenInputPrompt) ?? ""
        let system = getInputValue(for: node, portId: PortID.textGenInputSystem)

        var inputs: [String: String] = ["prompt": prompt]
        if let system {
            inputs["system"] = system
        }

        // Execute via API
        var output = ""

        do {
            let stream = await ExecutionService.shared.execute(
                nodeType: "text-generation",
                inputs: inputs,
                provider: data.provider,
                model: data.model
            )

            for try await event in stream {
                switch event {
                case .text(let text):
                    output += text
                    data.executionOutput = output
                    node.encodeData(data)

                case .error(let message):
                    data.executionStatus = .error
                    data.executionError = message
                    node.encodeData(data)
                    return

                case .done:
                    break

                default:
                    break
                }
            }

            // Success
            data.executionStatus = .success
            data.executionOutput = output
            node.encodeData(data)
            nodeOutputs[node.id] = output

        } catch {
            data.executionStatus = .error
            data.executionError = error.localizedDescription
            node.encodeData(data)
        }
    }

    /// Get the input value for a node's port from connected upstream node
    private func getInputValue(for node: FlowNode, portId: String) -> String? {
        // Find edge connected to this port
        guard let edge = node.incomingEdges.first(where: { $0.targetHandle == portId }),
              let sourceNode = edge.sourceNode else {
            return nil
        }

        // Return the output from the source node
        return nodeOutputs[sourceNode.id]
    }
}
