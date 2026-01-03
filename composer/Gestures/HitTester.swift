//
//  HitTester.swift
//  composer
//
//  Protocol-based hit testing for canvas elements
//

import Foundation
import CoreGraphics

/// Result of a hit test
enum HitTestResult: Equatable {
    case canvas
    case node(UUID)
    case port(nodeId: UUID, portId: String, isOutput: Bool)
    case edge(UUID)
}

/// Protocol for hit testable objects
protocol HitTestable {
    func hitTest(_ point: CGPoint, transform: (CGPoint) -> CGPoint) -> HitTestResult
}

/// Hit tester for canvas elements
struct HitTester: HitTestable {
    let nodes: [FlowNode]
    let edges: [FlowEdge]
    let nodeViewModels: [UUID: NodeViewModel]

    /// Radius for port hit testing (44pt touch target)
    private let portRadius: CGFloat = 22

    /// Tolerance for edge hit testing (px from curve)
    private let edgeTolerance: CGFloat = 8

    init(
        nodes: [FlowNode],
        edges: [FlowEdge],
        nodeViewModels: [UUID: NodeViewModel] = [:]
    ) {
        self.nodes = nodes
        self.edges = edges
        self.nodeViewModels = nodeViewModels
    }

    /// Perform hit test at the given screen point
    /// - Parameters:
    ///   - point: Point in screen coordinates
    ///   - transform: Function to convert screen to world coordinates
    /// - Returns: The hit test result
    func hitTest(_ point: CGPoint, transform: (CGPoint) -> CGPoint) -> HitTestResult {
        let worldPoint = transform(point)

        // Test ports first (highest priority)
        for node in nodes {
            let nodePosition = node.position
            let nodeSize = nodeViewModels[node.id]?.measuredSize ?? CGSize(width: 200, height: 100)

            // Test input ports (left side)
            for (index, port) in node.inputPorts.enumerated() {
                let portPosition = CGPoint(
                    x: nodePosition.x,
                    y: nodePosition.y + CGFloat(index + 1) * 30
                )
                if distance(from: worldPoint, to: portPosition) <= portRadius {
                    return .port(nodeId: node.id, portId: port.id, isOutput: false)
                }
            }

            // Test output ports (right side)
            for (index, port) in node.outputPorts.enumerated() {
                let portPosition = CGPoint(
                    x: nodePosition.x + nodeSize.width,
                    y: nodePosition.y + CGFloat(index + 1) * 30
                )
                if distance(from: worldPoint, to: portPosition) <= portRadius {
                    return .port(nodeId: node.id, portId: port.id, isOutput: true)
                }
            }
        }

        // Test nodes (second priority)
        for node in nodes.reversed() {  // Reversed so topmost node wins
            let nodePosition = node.position
            let nodeSize = nodeViewModels[node.id]?.measuredSize ?? CGSize(width: 200, height: 100)
            let nodeRect = CGRect(origin: nodePosition, size: nodeSize)

            if nodeRect.contains(worldPoint) {
                return .node(node.id)
            }
        }

        // Test edges (lowest priority)
        for edge in edges {
            if let dist = distanceToEdge(edge, from: worldPoint), dist <= edgeTolerance {
                return .edge(edge.id)
            }
        }

        // Nothing hit - canvas background
        return .canvas
    }

    /// Calculate distance from a point to an edge's bezier curve
    private func distanceToEdge(_ edge: FlowEdge, from point: CGPoint) -> CGFloat? {
        guard let sourceNode = edge.sourceNode,
              let targetNode = edge.targetNode else {
            return nil
        }

        let sourceSize = nodeViewModels[sourceNode.id]?.measuredSize ?? CGSize(width: 200, height: 100)

        // Calculate port positions
        let startPoint = CGPoint(
            x: sourceNode.position.x + sourceSize.width,
            y: sourceNode.position.y + 50
        )
        let endPoint = CGPoint(
            x: targetNode.position.x,
            y: targetNode.position.y + 50
        )

        return EdgeLayer.distanceToEdge(from: point, edgeStart: startPoint, edgeEnd: endPoint)
    }

    /// Calculate euclidean distance between two points
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        hypot(p1.x - p2.x, p1.y - p2.y)
    }
}
