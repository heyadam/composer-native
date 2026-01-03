//
//  CanvasPanGesture.swift
//  composer
//
//  Pan gesture for canvas viewport
//

import SwiftUI

/// Creates a pan gesture for the canvas
/// Updates canvasState.offset with momentum/inertia
struct CanvasPanGestureModifier: ViewModifier {
    @Binding var offset: CGSize
    let isEnabled: Bool

    @State private var lastOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .gesture(
                panGesture,
                isEnabled: isEnabled
            )
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                // Apply momentum
                let velocity = CGSize(
                    width: value.predictedEndTranslation.width - value.translation.width,
                    height: value.predictedEndTranslation.height - value.translation.height
                )

                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                    offset = CGSize(
                        width: offset.width + velocity.width * 0.3,
                        height: offset.height + velocity.height * 0.3
                    )
                }

                lastOffset = offset
            }
    }
}

extension View {
    /// Apply canvas pan gesture
    func canvasPanGesture(offset: Binding<CGSize>, isEnabled: Bool = true) -> some View {
        modifier(CanvasPanGestureModifier(offset: offset, isEnabled: isEnabled))
    }
}
