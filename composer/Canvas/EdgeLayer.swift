//
//  EdgeLayer.swift
//  composer
//
//  Renders bezier edges between nodes
//

import SwiftUI

struct EdgeLayer: View {
    let edges: [FlowEdge]
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?

    var body: some View {
        Canvas { context, size in
            for edge in edges {
                guard let sourceNode = edge.sourceNode,
                      let targetNode = edge.targetNode else { continue }

                let isSelected = state.isEdgeSelected(edge.id)

                // Look up actual port positions from the registry
                let sourcePortKey = "\(sourceNode.id):\(edge.sourceHandle)"
                let targetPortKey = "\(targetNode.id):\(edge.targetHandle)"

                // Get registered port positions (already in canvas coordinates)
                // Fall back to estimated positions if not yet registered
                let start: CGPoint
                let end: CGPoint

                if let sourcePos = state.portPositions[sourcePortKey],
                   let targetPos = state.portPositions[targetPortKey] {
                    // Use registered positions directly (already in screen/canvas coords)
                    start = sourcePos
                    end = targetPos
                } else {
                    // Fallback: estimate from node position (for edges created before ports register)
                    let sourcePosition = viewModel?.displayPosition(for: sourceNode.id) ?? sourceNode.position
                    let targetPosition = viewModel?.displayPosition(for: targetNode.id) ?? targetNode.position

                    let sourcePortOffset = CGPoint(x: 100, y: 50)
                    let targetPortOffset = CGPoint(x: 0, y: 50)

                    let startWorld = CGPoint(
                        x: sourcePosition.x + sourcePortOffset.x,
                        y: sourcePosition.y + sourcePortOffset.y
                    )
                    let endWorld = CGPoint(
                        x: targetPosition.x + targetPortOffset.x,
                        y: targetPosition.y + targetPortOffset.y
                    )

                    start = CoordinateTransform.worldToScreen(startWorld, offset: state.offset, scale: state.scale)
                    end = CoordinateTransform.worldToScreen(endWorld, offset: state.offset, scale: state.scale)
                }

                // Create bezier path
                let path = Self.edgePath(from: start, to: end)
                let color = edge.dataType.color

                // Draw glow for selected edges (in isolated layer to scope blur)
                if isSelected {
                    context.drawLayer { glowContext in
                        glowContext.addFilter(.blur(radius: 6))
                        glowContext.stroke(
                            path,
                            with: .color(color.opacity(0.6)),
                            style: StrokeStyle(lineWidth: 10 * state.scale, lineCap: .round)
                        )
                    }
                }

                // Draw main edge
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: (isSelected ? 3 : 2) * state.scale,
                        lineCap: .round
                    )
                )
            }
        }
        .drawingGroup()
    }

    /// Create a bezier path between two points
    static func edgePath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)

        let controlOffset = max(abs(end.x - start.x) * 0.5, 50)
        let control1 = CGPoint(x: start.x + controlOffset, y: start.y)
        let control2 = CGPoint(x: end.x - controlOffset, y: end.y)

        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }

    /// Calculate distance from a point to the edge bezier curve (for hit testing)
    static func distanceToEdge(from point: CGPoint, edgeStart: CGPoint, edgeEnd: CGPoint) -> CGFloat {
        // Sample points along the bezier and find minimum distance
        var minDistance: CGFloat = .infinity
        let sampleCount = 20

        for i in 0...sampleCount {
            let t = CGFloat(i) / CGFloat(sampleCount)
            let samplePoint = bezierPoint(at: t, from: edgeStart, to: edgeEnd)
            let distance = hypot(point.x - samplePoint.x, point.y - samplePoint.y)
            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    /// Calculate a point on the bezier curve at parameter t
    static func bezierPoint(at t: CGFloat, from start: CGPoint, to end: CGPoint) -> CGPoint {
        let controlOffset = max(abs(end.x - start.x) * 0.5, 50)
        let control1 = CGPoint(x: start.x + controlOffset, y: start.y)
        let control2 = CGPoint(x: end.x - controlOffset, y: end.y)

        // Cubic bezier formula
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t

        let x = mt3 * start.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * end.x
        let y = mt3 * start.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * end.y

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Edge Hit Testing Layer

struct EdgeHitTestingLayer: View {
    let edges: [FlowEdge]
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?

    private let hitTolerance: CGFloat = 8

    var body: some View {
        // Use invisible edge paths for hit testing instead of full-canvas contentShape
        // This prevents blocking node taps
        ForEach(edges) { edge in
            EdgeHitPath(edge: edge, state: state, viewModel: viewModel, hitTolerance: hitTolerance)
        }
    }

}

/// Individual edge hit path for targeted hit testing
private struct EdgeHitPath: View {
    let edge: FlowEdge
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?
    let hitTolerance: CGFloat

    var body: some View {
        if let path = edgePath {
            path
                .stroke(Color.clear, lineWidth: hitTolerance * 2 * state.scale)
                .contentShape(path.stroke(style: StrokeStyle(lineWidth: hitTolerance * 2 * state.scale)))
                .onTapGesture {
                    state.selectEdge(edge.id)
                }
        }
    }

    private var edgePath: Path? {
        guard let sourceNode = edge.sourceNode,
              let targetNode = edge.targetNode else { return nil }

        let sourcePortKey = "\(sourceNode.id):\(edge.sourceHandle)"
        let targetPortKey = "\(targetNode.id):\(edge.targetHandle)"

        let start: CGPoint
        let end: CGPoint

        if let sourcePos = state.portPositions[sourcePortKey],
           let targetPos = state.portPositions[targetPortKey] {
            start = sourcePos
            end = targetPos
        } else {
            // Fallback
            let sourcePosition = viewModel?.displayPosition(for: sourceNode.id) ?? sourceNode.position
            let targetPosition = viewModel?.displayPosition(for: targetNode.id) ?? targetNode.position

            let sourcePortOffset = CGPoint(x: 100, y: 50)
            let targetPortOffset = CGPoint(x: 0, y: 50)

            let startWorld = CGPoint(
                x: sourcePosition.x + sourcePortOffset.x,
                y: sourcePosition.y + sourcePortOffset.y
            )
            let endWorld = CGPoint(
                x: targetPosition.x + targetPortOffset.x,
                y: targetPosition.y + targetPortOffset.y
            )

            start = CoordinateTransform.worldToScreen(startWorld, offset: state.offset, scale: state.scale)
            end = CoordinateTransform.worldToScreen(endWorld, offset: state.offset, scale: state.scale)
        }

        // Create bezier path matching EdgeLayer
        var path = Path()
        let controlOffset = abs(end.x - start.x) * 0.5
        let cp1 = CGPoint(x: start.x + controlOffset, y: start.y)
        let cp2 = CGPoint(x: end.x - controlOffset, y: end.y)

        path.move(to: start)
        path.addCurve(to: end, control1: cp1, control2: cp2)

        return path
    }
}

// MARK: - Edge Context Menu Layer

struct EdgeContextMenuLayer: View {
    let edges: [FlowEdge]
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?

    var body: some View {
        ForEach(edges) { edge in
            EdgeContextMenuTarget(
                edge: edge,
                state: state,
                viewModel: viewModel
            )
        }
    }
}

private struct EdgeContextMenuTarget: View {
    let edge: FlowEdge
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?

    /// Touch target size scales inversely with zoom to maintain consistent interaction area
    private var targetSize: CGFloat {
        // Base size 44pt, scaled inversely so it covers consistent portion of edge
        // Clamped to reasonable range (32-64pt)
        let scaled = 44 / state.scale
        return min(max(scaled, 32), 64)
    }

    var body: some View {
        if let midpoint = edgeMidpoint {
            Color.clear
                .frame(width: targetSize, height: targetSize)
                .contentShape(Circle())
                .position(midpoint)
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel?.deleteEdge(edge.id)
                        state.selectedEdgeIds.remove(edge.id)
                    } label: {
                        Label("Delete Connection", systemImage: "trash")
                    }
                }
        }
    }

    private var edgeMidpoint: CGPoint? {
        guard let sourceNode = edge.sourceNode,
              let targetNode = edge.targetNode else { return nil }

        let sourcePortKey = "\(sourceNode.id):\(edge.sourceHandle)"
        let targetPortKey = "\(targetNode.id):\(edge.targetHandle)"

        guard let start = state.portPositions[sourcePortKey],
              let end = state.portPositions[targetPortKey] else { return nil }

        // Calculate midpoint of bezier (at t=0.5)
        return EdgeLayer.bezierPoint(at: 0.5, from: start, to: end)
    }
}

#Preview {
    let state = CanvasState()
    EdgeLayer(edges: [], state: state, viewModel: nil)
}
