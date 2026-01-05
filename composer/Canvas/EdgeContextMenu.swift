//
//  EdgeContextMenu.swift
//  composer
//
//  Context menu layer for edge right-click/long-press actions
//

import SwiftUI

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
