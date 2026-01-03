//
//  CanvasZoomGesture.swift
//  composer
//
//  Zoom gesture for canvas viewport with anchor point
//

import SwiftUI

/// Creates a zoom gesture for the canvas
/// Anchored to gesture centroid (trackpad cursor or pinch center)
struct CanvasZoomGestureModifier: ViewModifier {
    let canvasState: CanvasState
    let isEnabled: Bool

    @State private var lastScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .gesture(
                zoomGesture,
                isEnabled: isEnabled
            )
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Anchor zoom to gesture center
                // macOS trackpad: anchor to cursor position
                // iOS: anchor to pinch midpoint
                let anchor = value.startLocation
                let newScale = lastScale * value.magnification
                canvasState.zoom(to: newScale, anchor: anchor)
            }
            .onEnded { _ in
                lastScale = canvasState.scale
            }
    }
}

extension View {
    /// Apply canvas zoom gesture
    func canvasZoomGesture(state: CanvasState, isEnabled: Bool = true) -> some View {
        modifier(CanvasZoomGestureModifier(canvasState: state, isEnabled: isEnabled))
    }
}
