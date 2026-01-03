//
//  FlowNode.swift
//  composer
//
//  SwiftData model for a node in the flow graph
//

import Foundation
import SwiftData
import CoreGraphics

@Model
final class FlowNode {
    var id: UUID
    var nodeType: NodeType
    var positionX: Double
    var positionY: Double
    var label: String
    var dataJSON: Data?

    // Bidirectional relationship to Flow
    var flow: Flow?

    // Relationships for edges (not IDs)
    @Relationship(deleteRule: .cascade, inverse: \FlowEdge.sourceNode)
    var outgoingEdges: [FlowEdge] = []

    @Relationship(deleteRule: .cascade, inverse: \FlowEdge.targetNode)
    var incomingEdges: [FlowEdge] = []

    /// Convenience accessor for position as CGPoint
    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    init(
        id: UUID = UUID(),
        nodeType: NodeType,
        position: CGPoint = .zero,
        label: String = ""
    ) {
        self.id = id
        self.nodeType = nodeType
        self.positionX = position.x
        self.positionY = position.y
        self.label = label.isEmpty ? nodeType.displayName : label
    }

    /// Get input port definitions for this node
    var inputPorts: [PortDefinition] {
        NodePortSchemas.inputPorts(for: nodeType)
    }

    /// Get output port definitions for this node
    var outputPorts: [PortDefinition] {
        NodePortSchemas.outputPorts(for: nodeType)
    }

    /// Decode data from JSON storage
    func decodeData<T: Decodable>(_ type: T.Type) -> T? {
        guard let dataJSON else { return nil }
        return try? JSONDecoder().decode(type, from: dataJSON)
    }

    /// Encode data to JSON storage
    func encodeData<T: Encodable>(_ value: T) {
        dataJSON = try? JSONEncoder().encode(value)
    }
}

/// Data stored in TextInput nodes
struct TextInputData: Codable {
    var text: String = ""
}
