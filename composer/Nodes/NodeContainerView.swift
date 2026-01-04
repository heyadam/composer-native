//
//  NodeContainerView.swift
//  composer
//
//  Wraps node content with drag, selection, and context menu
//

import SwiftUI

struct NodeContainerView: View {
    let node: FlowNode
    let state: CanvasState
    let canvasViewModel: FlowCanvasViewModel?
    let connectionViewModel: ConnectionViewModel?

    @State private var nodeViewModel: NodeViewModel?
    @State private var lastDragPosition: CGPoint = .zero
    @State private var ignoringCurrentDrag = false

    var body: some View {
        nodeContent
            .overlay(selectionOverlay)  // Apply overlay before scale so it scales with node
            .scaleEffect(state.scale)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            nodeViewModel?.updateMeasuredSize(geometry.size)
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            nodeViewModel?.updateMeasuredSize(newSize)
                        }
                }
            )
            .position(screenPosition)
            .highPriorityGesture(nodeDragGesture)
            .highPriorityGesture(nodeTapGesture)
            #if os(iOS)
            .simultaneousGesture(nodeLongPressGesture)
            #endif
            .animation(.easeOut(duration: 0.15), value: state.isNodeSelected(node.id))
            .contextMenu {
                // Show selection info when multiple nodes selected
                if state.selectedNodeIds.count > 1 && state.isNodeSelected(node.id) {
                    Text("\(state.selectedNodeIds.count) nodes selected")
                        .font(.caption)
                    Divider()
                }

                Button(role: .destructive) {
                    if state.selectedNodeIds.count > 1 && state.isNodeSelected(node.id) {
                        // Delete all selected nodes
                        canvasViewModel?.deleteNodes(state.selectedNodeIds)
                        state.selectedNodeIds.removeAll()
                    } else {
                        // Delete just this node
                        canvasViewModel?.deleteNode(node.id)
                    }
                } label: {
                    if state.selectedNodeIds.count > 1 && state.isNodeSelected(node.id) {
                        Label("Delete \(state.selectedNodeIds.count) Nodes", systemImage: "trash")
                    } else {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(node.nodeType.displayName) node: \(node.label)")
            .accessibilityHint("Double tap to select")
            .task {
                nodeViewModel = NodeViewModel(node: node, canvasViewModel: canvasViewModel)
            }
    }

    // MARK: - Node Content

    @ViewBuilder
    private var nodeContent: some View {
        switch node.nodeType {
        case .textInput:
            TextInputNodeView(
                node: node,
                viewModel: nodeViewModel,
                state: state,
                connectionViewModel: connectionViewModel
            )

        case .textGeneration:
            TextGenerationNodeView(
                node: node,
                viewModel: nodeViewModel,
                state: state,
                connectionViewModel: connectionViewModel
            )

        case .previewOutput:
            PreviewOutputNodeView(
                node: node,
                viewModel: nodeViewModel,
                state: state,
                connectionViewModel: connectionViewModel
            )
        }
    }

    // MARK: - Position

    private var screenPosition: CGPoint {
        let worldPosition = canvasViewModel?.displayPosition(for: node.id) ?? node.position
        return CoordinateTransform.worldToScreen(
            worldPosition,
            offset: state.offset,
            scale: state.scale
        )
    }

    // MARK: - Selection Overlay

    @ViewBuilder
    private var selectionOverlay: some View {
        if state.isNodeSelected(node.id) {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor, lineWidth: 2.5)
                .padding(-3)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 6)
        }
    }

    // MARK: - Gestures

    private var nodeDragGesture: some Gesture {
        DragGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                // Don't drag if a connection drag is active
                if state.activeConnection != nil {
                    ignoringCurrentDrag = true
                    return
                }

                // On first touch, check if we started on a port
                if lastDragPosition == .zero && !ignoringCurrentDrag {
                    // Check if drag started on a port (should be handled by port gesture instead)
                    // Now using same coordinate space as port positions
                    if state.findPort(near: value.startLocation, excludingNode: nil) != nil {
                        ignoringCurrentDrag = true
                        return
                    }

                    // Start drag
                    lastDragPosition = node.position
                    state.isDraggingNode = true
                    canvasViewModel?.beginNodeDrag(node.id, at: node.position)

                    // Select on drag start if not already selected
                    if !state.isNodeSelected(node.id) {
                        state.selectNode(node.id)
                    }
                }

                if ignoringCurrentDrag { return }

                // Calculate world delta
                let screenDelta = CGSize(
                    width: value.translation.width,
                    height: value.translation.height
                )
                let worldDelta = CGSize(
                    width: screenDelta.width / state.scale,
                    height: screenDelta.height / state.scale
                )

                let newPosition = CGPoint(
                    x: lastDragPosition.x + worldDelta.width,
                    y: lastDragPosition.y + worldDelta.height
                )

                canvasViewModel?.updateNodeDrag(node.id, to: newPosition)
            }
            .onEnded { _ in
                // Only end drag if we actually started one
                if lastDragPosition != .zero {
                    canvasViewModel?.endNodeDrag(node.id)
                    lastDragPosition = .zero
                }
                state.isDraggingNode = false
                ignoringCurrentDrag = false
            }
    }

    private var nodeTapGesture: some Gesture {
        TapGesture()
            .onEnded {
                #if os(macOS)
                if NSEvent.modifierFlags.contains(.command) {
                    state.toggleNodeSelection(node.id)
                } else {
                    state.selectNode(node.id)
                }
                #else
                state.selectNode(node.id)
                #endif
            }
    }

    #if os(iOS)
    private var nodeLongPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                state.toggleNodeSelection(node.id)
            }
    }
    #endif
}

#Preview {
    let state = CanvasState()
    let flow = Flow(name: "Test")
    let node = FlowNode(nodeType: .textInput, position: CGPoint(x: 200, y: 200))

    ZStack {
        Color.black.ignoresSafeArea()
        NodeContainerView(
            node: node,
            state: state,
            canvasViewModel: nil,
            connectionViewModel: nil
        )
    }
}
