//
//  NodeDragGesture.swift
//  composer
//
//  Drag gesture for moving nodes
//  NOTE: This modifier is currently unused - NodeContainerView has its own inline gesture.
//  Kept for potential future multi-node drag implementation.
//

import SwiftUI

/// Creates a drag gesture for nodes
/// Updates transient position in ViewModel during drag, commits to SwiftData on end
struct NodeDragGestureModifier: ViewModifier {
    let node: FlowNode
    let canvasState: CanvasState
    let viewModel: FlowCanvasViewModel?

    @State private var startPosition: CGPoint = .zero
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                guard let viewModel else { return }

                if !isDragging {
                    // Start drag
                    isDragging = true
                    startPosition = viewModel.displayPosition(for: node.id) ?? .zero
                    viewModel.beginNodeDrag(node.id, at: startPosition)

                    // Select on drag if not already selected
                    if !canvasState.isNodeSelected(node.id) {
                        canvasState.selectNode(node.id)
                    }
                }

                // Calculate world delta from screen translation
                let worldDelta = CGSize(
                    width: value.translation.width / canvasState.scale,
                    height: value.translation.height / canvasState.scale
                )

                let newPosition = CGPoint(
                    x: startPosition.x + worldDelta.width,
                    y: startPosition.y + worldDelta.height
                )

                viewModel.updateNodeDrag(node.id, to: newPosition)
            }
            .onEnded { _ in
                guard let viewModel else { return }

                // Commit the drag - pass node directly to avoid stale flow.nodes issue
                viewModel.endNodeDrag(node)

                isDragging = false
                startPosition = .zero
            }
    }
}

extension View {
    /// Apply node drag gesture
    func nodeDragGesture(
        node: FlowNode,
        state: CanvasState,
        viewModel: FlowCanvasViewModel?
    ) -> some View {
        modifier(NodeDragGestureModifier(
            node: node,
            canvasState: state,
            viewModel: viewModel
        ))
    }
}
