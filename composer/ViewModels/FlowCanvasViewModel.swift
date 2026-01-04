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

    /// Whether any nodes are currently being dragged
    var isDragging: Bool { !draggedNodePositions.isEmpty }

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
        draggedNodePositions[nodeId] = position
    }

    /// Update node position during drag (transient, no SwiftData write)
    func updateNodeDrag(_ nodeId: UUID, to position: CGPoint) {
        draggedNodePositions[nodeId] = position
    }

    /// End drag and commit position to SwiftData
    func endNodeDrag(_ nodeId: UUID) {
        guard let finalPosition = draggedNodePositions[nodeId],
              let node = flow.nodes.first(where: { $0.id == nodeId }) else {
            draggedNodePositions.removeValue(forKey: nodeId)
            return
        }

        node.position = finalPosition
        flow.touch()
        draggedNodePositions.removeValue(forKey: nodeId)
    }

    /// Get current display position for a node (transient or persisted)
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
    }

    /// Delete nodes by IDs
    func deleteNodes(_ ids: Set<UUID>) {
        let nodesToDelete = flow.nodes.filter { ids.contains($0.id) }
        for node in nodesToDelete {
            // Edges will be cascade deleted due to relationship rules
            flow.nodes.removeAll { $0.id == node.id }
            modelContext.delete(node)
        }
        flow.touch()
    }

    /// Delete a single node
    func deleteNode(_ nodeId: UUID) {
        deleteNodes([nodeId])
    }

    // MARK: - Edge Operations

    /// Create an edge between two connection points
    func createEdge(from source: ConnectionPoint, to target: ConnectionPoint) throws {
        // Validate: source must be output, target must be input
        guard source.isOutput && !target.isOutput else {
            throw FlowError.invalidConnection
        }

        // Validate port compatibility
        guard NodePortSchemas.canConnect(sourceType: source.portType, targetType: target.portType) else {
            throw FlowError.incompatiblePorts
        }

        // Find nodes
        guard let sourceNode = flow.nodes.first(where: { $0.id == source.nodeId }),
              let targetNode = flow.nodes.first(where: { $0.id == target.nodeId }) else {
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

        // Create edge
        let edge = FlowEdge(
            sourceHandle: source.portId,
            targetHandle: target.portId,
            dataType: source.portType,
            sourceNode: sourceNode,
            targetNode: targetNode
        )
        edge.flow = flow
        flow.edges.append(edge)
        flow.touch()
        modelContext.insert(edge)
    }

    /// Delete an edge by ID
    func deleteEdge(_ edgeId: UUID) {
        guard let edge = flow.edges.first(where: { $0.id == edgeId }) else { return }
        flow.edges.removeAll { $0.id == edgeId }
        modelContext.delete(edge)
        flow.touch()
    }

    /// Delete edges by IDs
    func deleteEdges(_ ids: Set<UUID>) {
        let edgesToDelete = flow.edges.filter { ids.contains($0.id) }
        for edge in edgesToDelete {
            flow.edges.removeAll { $0.id == edge.id }
            modelContext.delete(edge)
        }
        flow.touch()
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

        isExecuting = true
        nodeOutputs.removeAll()

        // Topological sort nodes
        let sortedNodes = topologicalSort()

        // Execute each node in order
        for node in sortedNodes {
            await executeNode(node)
        }

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
