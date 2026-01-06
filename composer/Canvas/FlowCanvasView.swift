//
//  FlowCanvasView.swift
//  composer
//
//  Main canvas container for the flow editor
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

/// Named coordinate space for the canvas
enum CanvasCoordinateSpace {
    static let name = "flowCanvas"
}

struct FlowCanvasView: View {
    let flow: Flow
    var onViewModelCreated: ((FlowCanvasViewModel) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var canvasState = CanvasState()
    @State private var viewModel: FlowCanvasViewModel?
    @State private var connectionViewModel: ConnectionViewModel?

    // Gesture state
    @State private var lastPanOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    // Focus state for keyboard handling (iOS only)
    #if os(iOS)
    @FocusState private var canvasFocused: Bool
    #endif

    // MARK: - View Body

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

                // Edge hit testing (tap to select) - below nodes so nodes win taps
                EdgeHitTestingLayer(
                    edges: flow.edges,
                    state: canvasState,
                    viewModel: viewModel
                )

                // Edge context menus (for right-click/long-press delete)
                EdgeContextMenuLayer(
                    edges: flow.edges,
                    state: canvasState,
                    viewModel: viewModel
                )

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

                // Selection count badge
                if canvasState.selectionCount > 1 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            SelectionBadge(count: canvasState.selectionCount)
                                .padding()
                        }
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: canvasState.selectionCount)
            .coordinateSpace(name: CanvasCoordinateSpace.name)
            .preference(key: CanvasSizeKey.self, value: geometry.size)
            // Canvas gestures - disabled while editing text
            // Use simultaneousGesture for pan to allow node gestures to take priority
            .simultaneousGesture(canvasPanGesture, isEnabled: !canvasState.isEditingNode)
            .simultaneousGesture(canvasZoomGesture, isEnabled: !canvasState.isEditingNode)
            .simultaneousGesture(canvasTapGesture)
        }
        .onPreferenceChange(CanvasSizeKey.self) { size in
            canvasState.updateCanvasSize(size)
        }
        .task {
            let vm = FlowCanvasViewModel(flow: flow, context: modelContext)
            viewModel = vm
            connectionViewModel = ConnectionViewModel(canvasViewModel: vm, canvasState: canvasState)
            onViewModelCreated?(vm)
        }
        #if os(macOS)
        .background(
            ScrollWheelModifier(
                onScroll: { delta, location in
                    // Option+scroll or pinch to zoom
                    if NSEvent.modifierFlags.contains(.option) {
                        let zoomDelta = 1.0 + (delta * 0.01)
                        let newScale = canvasState.scale * zoomDelta
                        canvasState.zoom(to: newScale, anchor: location)
                        lastScale = canvasState.scale
                        // Sync pan offset to prevent jump on next pan
                        lastPanOffset = canvasState.offset
                    }
                },
                onDelete: {
                    // Guard against deletion while editing text or when nothing selected
                    guard !canvasState.isEditingNode, canvasState.hasSelection else { return }
                    deleteSelected()
                }
            )
        )
        #else
        // iOS: Use UIKeyCommand with persistent first responder
        .background(
            KeyboardDeleteHandler(
                canDelete: { !canvasState.isEditingNode && canvasState.hasSelection },
                onDelete: deleteSelected
            )
        )
        #endif
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Don't pan if dragging a node or creating a connection
                guard !canvasState.isDraggingNode && canvasState.activeConnection == nil else { return }
                canvasState.offset = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                // Only update if we weren't dragging a node or connection
                guard !canvasState.isDraggingNode && canvasState.activeConnection == nil else { return }
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
                // Sync pan offset to prevent jump on next pan
                lastPanOffset = canvasState.offset
            }
            .onEnded { _ in
                lastScale = canvasState.scale
                // Ensure pan offset is synced after zoom completes
                lastPanOffset = canvasState.offset
            }
    }

    private var canvasTapGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onEnded { value in
                // Check what was tapped
                let tappedNode = hitTestNode(at: value.location)
                let tappedEdge = hitTestEdge(at: value.location)

                if tappedNode != nil {
                    // Nodes handle their own selection via NodeContainerView
                    return
                } else if let edgeId = tappedEdge {
                    // Select the tapped edge
                    canvasState.selectEdge(edgeId)
                } else {
                    // Tapped empty canvas - clear selection
                    canvasState.clearSelection()
                    dismissKeyboard()
                }
            }
    }

    // MARK: - Hit Testing

    private func hitTestNode(at location: CGPoint) -> UUID? {
        for node in flow.nodes {
            let worldPos = viewModel?.displayPosition(for: node.id) ?? node.position
            let screenPos = CoordinateTransform.worldToScreen(worldPos, offset: canvasState.offset, scale: canvasState.scale)

            // Approximate node bounds (scaled)
            let nodeWidth: CGFloat = 220 * canvasState.scale
            let nodeHeight: CGFloat = 150 * canvasState.scale
            let nodeRect = CGRect(
                x: screenPos.x - nodeWidth / 2,
                y: screenPos.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )

            if nodeRect.contains(location) {
                return node.id
            }
        }
        return nil
    }

    private func hitTestEdge(at location: CGPoint) -> UUID? {
        for edge in flow.edges {
            guard let sourceNode = edge.sourceNode,
                  let targetNode = edge.targetNode else { continue }

            let sourcePortKey = "\(sourceNode.id):\(edge.sourceHandle)"
            let targetPortKey = "\(targetNode.id):\(edge.targetHandle)"

            let start: CGPoint
            let end: CGPoint

            if let sourcePos = canvasState.portPositions[sourcePortKey],
               let targetPos = canvasState.portPositions[targetPortKey] {
                start = sourcePos
                end = targetPos
            } else {
                continue
            }

            let distance = EdgeLayer.distanceToEdge(from: location, edgeStart: start, edgeEnd: end)
            // 22pt hit radius for touch-friendly target (matches EdgeHitTestingLayer)
            if distance < 22 * canvasState.scale {
                return edge.id
            }
        }
        return nil
    }

    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #else
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
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
        // Wrap nodes in GlassEffectContainer for better blending and morphing
        // Scale applied at container level (not individual nodes) for glass coherence
        GlassEffectContainer(spacing: 60.0) {
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
        .scaleEffect(state.scale, anchor: .topLeading)
    }
}

// MARK: - Selection Badge

struct SelectionBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("\(count) selected")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .glassEffect(.regular.tint(.accentColor), in: .capsule)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - macOS Input Handler (Scroll Wheel + Keyboard)

#if os(macOS)
import AppKit

struct ScrollWheelModifier: NSViewRepresentable {
    let onScroll: (CGFloat, CGPoint) -> Void
    var onDelete: (() -> Void)?

    func makeNSView(context: Context) -> CanvasInputView {
        let view = CanvasInputView()
        view.onScroll = onScroll
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: CanvasInputView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onDelete = onDelete
    }

    class CanvasInputView: NSView {
        var onScroll: ((CGFloat, CGPoint) -> Void)?
        var onDelete: (() -> Void)?
        private var eventMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if window != nil {
                // Set up local event monitor for key events
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    // Delete key (0x33 = backspace, 0x75 = forward delete)
                    if event.keyCode == 0x33 || event.keyCode == 0x75 {
                        // Only handle if no text field is focused
                        if let firstResponder = self?.window?.firstResponder,
                           !(firstResponder is NSTextView || firstResponder is NSTextField) {
                            self?.onDelete?()
                            return nil // Consume the event
                        }
                    }
                    return event // Pass through other events
                }
            } else {
                // Remove monitor when view is removed from window
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    eventMonitor = nil
                }
            }
        }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        override func scrollWheel(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            // Use scrollingDeltaY for smooth scrolling
            let delta = event.scrollingDeltaY
            onScroll?(delta, location)
        }
    }
}
#endif

// MARK: - iOS Input Handler (Keyboard)

#if os(iOS)
// Helper to find current first responder
extension UIResponder {
    private static weak var _currentFirstResponder: UIResponder?

    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }

    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
}

struct KeyboardDeleteHandler: UIViewControllerRepresentable {
    let canDelete: () -> Bool
    let onDelete: () -> Void

    func makeUIViewController(context: Context) -> KeyboardDeleteViewController {
        let vc = KeyboardDeleteViewController()
        vc.canDelete = canDelete
        vc.onDelete = onDelete
        return vc
    }

    func updateUIViewController(_ uiViewController: KeyboardDeleteViewController, context: Context) {
        uiViewController.canDelete = canDelete
        uiViewController.onDelete = onDelete
    }

    class KeyboardDeleteViewController: UIViewController {
        var canDelete: (() -> Bool)?
        var onDelete: (() -> Void)?
        private var refocusTimer: Timer?

        override var canBecomeFirstResponder: Bool { true }

        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(
                    action: #selector(handleDelete),
                    input: UIKeyCommand.inputDelete
                ),
                UIKeyCommand(
                    action: #selector(handleDelete),
                    input: "\u{8}" // Backspace
                )
            ]
        }

        @objc private func handleDelete() {
            let canDeleteResult = canDelete?() ?? false
            print("⌨️ DELETE KEY pressed - canDelete: \(canDeleteResult)")
            guard canDeleteResult else { return }
            print("⌨️ Executing delete!")
            onDelete?()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()

            // Periodically reclaim first responder if we lost it
            // (except when a text field is active)
            refocusTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if !self.isFirstResponder {
                    // Don't steal focus from text fields
                    if let firstResponder = UIResponder.currentFirstResponder,
                       firstResponder is UITextView || firstResponder is UITextField {
                        return
                    }
                    self.becomeFirstResponder()
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            refocusTimer?.invalidate()
            refocusTimer = nil
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
