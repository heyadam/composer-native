//
//  FlowCanvasView.swift
//  composer
//
//  Main canvas container for the flow editor
//

import SwiftUI
import SwiftData

/// Named coordinate space for the canvas
enum CanvasCoordinateSpace {
    static let name = "flowCanvas"
}

struct FlowCanvasView: View {
    let flow: Flow
    @Environment(\.modelContext) private var modelContext
    @State private var canvasState = CanvasState()
    @State private var viewModel: FlowCanvasViewModel?
    @State private var connectionViewModel: ConnectionViewModel?

    // Gesture state
    @State private var lastPanOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Grid
                GridBackground(state: canvasState)

                // Edges
                EdgeLayer(
                    edges: flow.edges,
                    state: canvasState,
                    viewModel: viewModel
                )
                .allowsHitTesting(false)

                // Connection preview
                ConnectionPreview(
                    state: canvasState,
                    connectionViewModel: connectionViewModel
                )
                .allowsHitTesting(false)

                // Nodes
                NodeLayer(
                    nodes: flow.nodes,
                    state: canvasState,
                    viewModel: viewModel,
                    connectionViewModel: connectionViewModel
                )
            }
            .coordinateSpace(name: CanvasCoordinateSpace.name)
            .preference(key: CanvasSizeKey.self, value: geometry.size)
            .contentShape(Rectangle())  // Make entire area tappable
            // Canvas gestures - disabled while editing text
            .gesture(canvasPanGesture, isEnabled: !canvasState.isEditingNode)
            .simultaneousGesture(canvasZoomGesture, isEnabled: !canvasState.isEditingNode)
            .simultaneousGesture(canvasTapGesture)
        }
        .onPreferenceChange(CanvasSizeKey.self) { size in
            canvasState.updateCanvasSize(size)
        }
        .task {
            viewModel = FlowCanvasViewModel(flow: flow, context: modelContext)
            connectionViewModel = ConnectionViewModel(canvasViewModel: viewModel, canvasState: canvasState)
        }
        #if os(macOS)
        .onDeleteCommand {
            deleteSelected()
        }
        .background(
            ScrollWheelModifier { delta, location in
                // Option+scroll or pinch to zoom
                if NSEvent.modifierFlags.contains(.option) {
                    let zoomDelta = 1.0 + (delta * 0.01)
                    let newScale = canvasState.scale * zoomDelta
                    canvasState.zoom(to: newScale, anchor: location)
                    lastScale = canvasState.scale
                }
            }
        )
        #endif
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                canvasState.offset = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPanOffset = canvasState.offset
            }
    }

    private var canvasZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Anchor zoom to gesture center
                let anchor = value.startLocation
                let newScale = lastScale * value.magnification
                canvasState.zoom(to: newScale, anchor: anchor)
            }
            .onEnded { _ in
                lastScale = canvasState.scale
            }
    }

    private var canvasTapGesture: some Gesture {
        TapGesture()
            .onEnded {
                canvasState.clearSelection()
            }
    }

    // MARK: - Actions

    private func deleteSelected() {
        guard let viewModel else { return }

        if !canvasState.selectedNodeIds.isEmpty {
            viewModel.deleteNodes(canvasState.selectedNodeIds)
            canvasState.selectedNodeIds.removeAll()
        }

        if !canvasState.selectedEdgeIds.isEmpty {
            viewModel.deleteEdges(canvasState.selectedEdgeIds)
            canvasState.selectedEdgeIds.removeAll()
        }
    }
}

// MARK: - Node Layer

struct NodeLayer: View {
    let nodes: [FlowNode]
    let state: CanvasState
    let viewModel: FlowCanvasViewModel?
    let connectionViewModel: ConnectionViewModel?

    var body: some View {
        ForEach(nodes) { node in
            NodeContainerView(
                node: node,
                state: state,
                canvasViewModel: viewModel,
                connectionViewModel: connectionViewModel
            )
            .id(node.id)  // Explicit identity for SwiftUI
        }
    }
}

// MARK: - macOS Scroll Wheel Handler

#if os(macOS)
import AppKit

struct ScrollWheelModifier: NSViewRepresentable {
    let onScroll: (CGFloat, CGPoint) -> Void

    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelView, context: Context) {
        nsView.onScroll = onScroll
    }

    class ScrollWheelView: NSView {
        var onScroll: ((CGFloat, CGPoint) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            // Use scrollingDeltaY for smooth scrolling
            let delta = event.scrollingDeltaY
            onScroll?(delta, location)
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    @Previewable @State var flow = Flow(name: "Test Flow")

    FlowCanvasView(flow: flow)
        .modelContainer(for: [Flow.self, FlowNode.self, FlowEdge.self], inMemory: true)
}
