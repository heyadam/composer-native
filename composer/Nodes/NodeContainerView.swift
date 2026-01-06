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
            .overlay(selectionOverlay)
            // Scale handled at GlassEffectContainer level in NodeLayer
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
            .gesture(nodeDragGesture)
            .gesture(nodeTapGesture)
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
        // Use NodeRegistry for type-erased view creation - no switch needed!
        NodeRegistry.makeContentView(
            for: node,
            viewModel: nodeViewModel,
            state: state,
            connectionViewModel: connectionViewModel
        )
    }

    // MARK: - Position

    private var screenPosition: CGPoint {
        // Use transient position during drag, otherwise read directly from node
        // Reading node.position directly ensures proper SwiftData observation
        let worldPosition = canvasViewModel?.transientPosition(for: node.id) ?? node.position
        // Position in pre-scaled space - GlassEffectContainer handles scaling
        // Final position: (worldPos + offset/scale) * scale = worldPos*scale + offset
        return CGPoint(
            x: worldPosition.x + state.offset.width / state.scale,
            y: worldPosition.y + state.offset.height / state.scale
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
        // Use higher minimumDistance so port gestures (minimumDistance: 0) claim touches first
        DragGesture(minimumDistance: 8, coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                // Always check if a connection drag is active (port gesture may have claimed it)
                if state.activeConnection != nil {
                    ignoringCurrentDrag = true
                }

                if ignoringCurrentDrag { return }

                // On first touch, check if we started on a port
                if lastDragPosition == .zero {
                    // Check if drag started on a port - use larger hit radius for reliability
                    // The returned tuple includes isOutput but we only need to check existence here
                    if state.findPort(near: value.startLocation, excludingNode: nil, hitRadius: 30) != nil {
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
            .onEnded { value in
                // Only end drag if we actually started one
                if lastDragPosition != .zero {
                    // Calculate final position from the gesture end value
                    // (iPad may not call onChanged with the final position before onEnded)
                    let screenDelta = CGSize(
                        width: value.translation.width,
                        height: value.translation.height
                    )
                    let worldDelta = CGSize(
                        width: screenDelta.width / state.scale,
                        height: screenDelta.height / state.scale
                    )
                    let finalPosition = CGPoint(
                        x: lastDragPosition.x + worldDelta.width,
                        y: lastDragPosition.y + worldDelta.height
                    )

                    canvasViewModel?.updateNodeDrag(node.id, to: finalPosition)
                    // Pass node directly - DO NOT use node ID lookup (see endNodeDrag docs)
                    canvasViewModel?.endNodeDrag(node)
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
