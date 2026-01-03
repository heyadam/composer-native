//
//  SelectionGesture.swift
//  composer
//
//  Gestures for selecting nodes and edges
//

import SwiftUI

/// Selection gesture modifier for nodes
struct NodeSelectionGestureModifier: ViewModifier {
    let nodeId: UUID
    let canvasState: CanvasState

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(tapGesture)
            #if os(iOS)
            .simultaneousGesture(longPressGesture)
            #endif
    }

    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                #if os(macOS)
                // Cmd+click for multi-select on macOS
                if NSEvent.modifierFlags.contains(.command) {
                    canvasState.toggleNodeSelection(nodeId)
                } else {
                    canvasState.selectNode(nodeId)
                }
                #else
                // Single tap selects on iOS
                canvasState.selectNode(nodeId)
                #endif
            }
    }

    #if os(iOS)
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                // Long press for multi-select on iOS
                canvasState.toggleNodeSelection(nodeId)
            }
    }
    #endif
}

/// Selection gesture modifier for edges
struct EdgeSelectionGestureModifier: ViewModifier {
    let edgeId: UUID
    let canvasState: CanvasState

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(tapGesture)
    }

    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                canvasState.selectEdge(edgeId)
            }
    }
}

/// Canvas background tap gesture for clearing selection
struct CanvasClearSelectionGestureModifier: ViewModifier {
    let canvasState: CanvasState

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(tapGesture)
    }

    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                canvasState.clearSelection()
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply node selection gesture
    func nodeSelectionGesture(nodeId: UUID, state: CanvasState) -> some View {
        modifier(NodeSelectionGestureModifier(nodeId: nodeId, canvasState: state))
    }

    /// Apply edge selection gesture
    func edgeSelectionGesture(edgeId: UUID, state: CanvasState) -> some View {
        modifier(EdgeSelectionGestureModifier(edgeId: edgeId, canvasState: state))
    }

    /// Apply canvas clear selection gesture
    func canvasClearSelectionGesture(state: CanvasState) -> some View {
        modifier(CanvasClearSelectionGestureModifier(canvasState: state))
    }
}
