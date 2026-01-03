//
//  NodeDragGesture.swift
//  composer
//
//  Drag gesture for moving nodes
//

import SwiftUI

/// Creates a drag gesture for nodes
/// Updates transient position in ViewModel during drag, commits to SwiftData on end
struct NodeDragGestureModifier: ViewModifier {
    let nodeId: UUID
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
                    startPosition = viewModel.displayPosition(for: nodeId) ?? .zero
                    viewModel.beginNodeDrag(nodeId, at: startPosition)

                    // Select on drag if not already selected
                    if !canvasState.isNodeSelected(nodeId) {
                        canvasState.selectNode(nodeId)
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

                viewModel.updateNodeDrag(nodeId, to: newPosition)

                // If multiple nodes selected, move them all together
                for selectedId in canvasState.selectedNodeIds where selectedId != nodeId {
                    if let selectedStart = viewModel.displayPosition(for: selectedId) {
                        // This is simplified - in a full implementation we'd track
                        // start positions for all selected nodes
                        viewModel.updateNodeDrag(selectedId, to: CGPoint(
                            x: selectedStart.x + worldDelta.width,
                            y: selectedStart.y + worldDelta.height
                        ))
                    }
                }
            }
            .onEnded { _ in
                guard let viewModel else { return }

                // Commit all dragged nodes
                viewModel.endNodeDrag(nodeId)
                for selectedId in canvasState.selectedNodeIds where selectedId != nodeId {
                    viewModel.endNodeDrag(selectedId)
                }

                isDragging = false
                startPosition = .zero
            }
    }
}

extension View {
    /// Apply node drag gesture
    func nodeDragGesture(
        nodeId: UUID,
        state: CanvasState,
        viewModel: FlowCanvasViewModel?
    ) -> some View {
        modifier(NodeDragGestureModifier(
            nodeId: nodeId,
            canvasState: state,
            viewModel: viewModel
        ))
    }
}
