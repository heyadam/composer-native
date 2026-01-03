//
//  FlowEdge.swift
//  composer
//
//  SwiftData model for an edge (connection) between nodes
//

import Foundation
import SwiftData

@Model
final class FlowEdge {
    var id: UUID
    var sourceHandle: String  // Port identifier on source node
    var targetHandle: String  // Port identifier on target node
    var dataType: PortDataType

    // Bidirectional relationship to Flow
    var flow: Flow?

    // Actual relationships to nodes (not string IDs)
    var sourceNode: FlowNode?
    var targetNode: FlowNode?

    init(
        id: UUID = UUID(),
        sourceHandle: String,
        targetHandle: String,
        dataType: PortDataType,
        sourceNode: FlowNode? = nil,
        targetNode: FlowNode? = nil
    ) {
        self.id = id
        self.sourceHandle = sourceHandle
        self.targetHandle = targetHandle
        self.dataType = dataType
        self.sourceNode = sourceNode
        self.targetNode = targetNode
    }

    /// Validate that the edge has valid node connections
    var isValid: Bool {
        sourceNode != nil && targetNode != nil
    }
}
