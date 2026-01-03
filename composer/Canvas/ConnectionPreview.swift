//
//  ConnectionPreview.swift
//  composer
//
//  Temporary line during connection drag
//

import SwiftUI

struct ConnectionPreview: View {
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    /// Animated dash phase for visual feedback
    @State private var dashPhase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            guard let connectionVM = connectionViewModel,
                  connectionVM.isConnecting,
                  let sourcePoint = connectionVM.sourcePoint,
                  let endPosition = connectionVM.connectionEndPosition else {
                return
            }

            // Get start position from registered port position (already in screen coords)
            let portKey = "\(sourcePoint.nodeId):\(sourcePoint.portId)"
            let start = state.portPositions[portKey] ?? CoordinateTransform.worldToScreen(
                sourcePoint.position,
                offset: state.offset,
                scale: state.scale
            )

            // End position is already in screen coordinates from drag gesture
            let end = endPosition

            // Create bezier path
            let path = EdgeLayer.edgePath(from: start, to: end)

            // Color based on source port type
            let color = sourcePoint.portType.color

            // Draw with animated dashed stroke
            context.stroke(
                path,
                with: .color(color.opacity(0.8)),
                style: StrokeStyle(
                    lineWidth: 2 * state.scale,
                    lineCap: .round,
                    dash: [8, 4],
                    dashPhase: dashPhase
                )
            )

            // Draw glow effect
            context.stroke(
                path,
                with: .color(color.opacity(0.3)),
                style: StrokeStyle(
                    lineWidth: 6 * state.scale,
                    lineCap: .round
                )
            )
        }
        .drawingGroup()
        .onAppear {
            // Animate dash phase
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                dashPhase = 12
            }
        }
    }
}

#Preview {
    let state = CanvasState()
    ConnectionPreview(state: state, connectionViewModel: nil)
}
