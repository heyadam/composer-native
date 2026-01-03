//
//  GridBackground.swift
//  composer
//
//  Dot grid background for the canvas
//

import SwiftUI

struct GridBackground: View {
    let state: CanvasState

    /// Grid spacing in world units
    private let gridSpacing: CGFloat = 20

    /// Dot radius in screen units
    private let dotRadius: CGFloat = 1.5

    /// Dot color
    private let dotColor = Color.white.opacity(0.15)

    var body: some View {
        Canvas { context, size in
            let visibleRect = CoordinateTransform.visibleWorldRect(
                canvasSize: size,
                offset: state.offset,
                scale: state.scale
            )

            // Calculate grid bounds (expanded to ensure full coverage)
            let startX = floor(visibleRect.minX / gridSpacing) * gridSpacing
            let startY = floor(visibleRect.minY / gridSpacing) * gridSpacing
            let endX = ceil(visibleRect.maxX / gridSpacing) * gridSpacing
            let endY = ceil(visibleRect.maxY / gridSpacing) * gridSpacing

            // Don't render if zoomed out too far (too many dots)
            let scaledSpacing = gridSpacing * state.scale
            guard scaledSpacing >= 8 else { return }

            // Draw dots
            var x = startX
            while x <= endX {
                var y = startY
                while y <= endY {
                    let screenPoint = CoordinateTransform.worldToScreen(
                        CGPoint(x: x, y: y),
                        offset: state.offset,
                        scale: state.scale
                    )

                    let dotRect = CGRect(
                        x: screenPoint.x - dotRadius,
                        y: screenPoint.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )

                    context.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(dotColor)
                    )

                    y += gridSpacing
                }
                x += gridSpacing
            }
        }
        .drawingGroup()  // Flatten for performance
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.black
        GridBackground(state: CanvasState())
    }
}
