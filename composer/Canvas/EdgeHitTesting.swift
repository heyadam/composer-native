//
//  EdgeHitTesting.swift
//  composer
//
//  Hit testing layer for edge tap-to-select
//

import SwiftUI

struct EdgeHitTestingLayer: View {
    let edges: [FlowEdge]
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?

    // 22pt radius = 44pt diameter touch target (Apple HIG minimum)
    private let hitTolerance: CGFloat = 22

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
        let controlOffset = max(abs(end.x - start.x) * 0.5, 50)
        let cp1 = CGPoint(x: start.x + controlOffset, y: start.y)
        let cp2 = CGPoint(x: end.x - controlOffset, y: end.y)

        path.move(to: start)
        path.addCurve(to: end, control1: cp1, control2: cp2)

        return path
    }
}
