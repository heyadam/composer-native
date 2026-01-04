//
//  PortView.swift
//  composer
//
//  Port circles with connection gestures
//

import SwiftUI

struct PortView: View {
    let port: PortDefinition
    let isOutput: Bool
    let nodeId: UUID?
    let canvasState: CanvasState?
    let connectionViewModel: ConnectionViewModel?

    @State private var isHovered = false
    @State private var isDragging = false
    @State private var showConnectionError = false

    /// Port circle size
    private let normalSize: CGFloat = 14
    private let hoverSize: CGFloat = 18

    /// Hit target for accessibility
    private let hitTargetSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 6) {
            if isOutput {
                portLabel
                portCircleWithGesture
            } else {
                portCircleWithGesture
                portLabel
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .offset(x: showConnectionError ? -4 : 0)
    }

    /// Port circle with gesture applied directly for reliable hit testing
    private var portCircleWithGesture: some View {
        ZStack {
            // Invisible hit target - larger than visual circle
            Circle()
                .fill(Color.clear)
                .frame(width: hitTargetSize, height: hitTargetSize)

            // Visual circle (centered)
            portCircle
        }
        .contentShape(Circle())
        .highPriorityGesture(connectionDragGesture)
    }

    private var portLabel: some View {
        Text(port.label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var portCircle: some View {
        Circle()
            .fill(port.dataType.color)
            .frame(
                width: (isHovered || isDragging) ? hoverSize : normalSize,
                height: (isHovered || isDragging) ? hoverSize : normalSize
            )
            .shadow(color: port.dataType.color.opacity(isDragging ? 0.6 : 0.3), radius: isDragging ? 6 : 3)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .onHover { hovering in
                isHovered = hovering
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            registerCirclePosition(geometry.frame(in: .named(CanvasCoordinateSpace.name)))
                        }
                        .onChange(of: geometry.frame(in: .named(CanvasCoordinateSpace.name))) { _, frame in
                            registerCirclePosition(frame)
                        }
                }
            )
            .accessibilityLabel("\(port.dataType.displayName) \(isOutput ? "output" : "input") port")
            .accessibilityHint("Double tap to connect")
            .accessibilityAddTraits(.isButton)
    }

    private func registerCirclePosition(_ frame: CGRect) {
        guard let nodeId, let canvasState else { return }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        canvasState.registerPort(
            nodeId: nodeId,
            portId: port.id,
            isOutput: isOutput,
            dataType: port.dataType,
            position: center
        )
    }

    private var connectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                guard let canvasState, let connectionViewModel, let nodeId else { return }

                if !isDragging {
                    isDragging = true

                    // Use registered port position (center of circle) instead of touch location
                    let portKey = "\(nodeId):\(port.id)"
                    let portScreenPosition = canvasState.portPositions[portKey] ?? value.startLocation

                    let sourcePoint = ConnectionPoint(
                        nodeId: nodeId,
                        portId: port.id,
                        portType: port.dataType,
                        isOutput: isOutput,
                        position: canvasState.canvasToWorld(portScreenPosition)
                    )

                    connectionViewModel.beginConnection(from: sourcePoint)
                    canvasState.activeConnection = sourcePoint
                }

                canvasState.connectionEndPosition = value.location
                connectionViewModel.updateConnection(to: value.location)
            }
            .onEnded { value in
                defer {
                    isDragging = false
                    canvasState?.activeConnection = nil
                    canvasState?.connectionEndPosition = nil
                }

                guard let canvasState, let connectionViewModel, let nodeId else { return }

                // Check if we dropped over a compatible port
                if let hitPort = canvasState.findPort(near: value.location, excludingNode: nodeId) {
                    // Get the data type from registry (O(1) lookup)
                    let targetDataType = canvasState.portDataType(nodeId: hitPort.nodeId, portId: hitPort.portId) ?? .string

                    let targetPoint = ConnectionPoint(
                        nodeId: hitPort.nodeId,
                        portId: hitPort.portId,
                        portType: targetDataType,
                        isOutput: !isOutput  // Target should be opposite direction
                    )

                    if connectionViewModel.canConnect(to: targetPoint) {
                        do {
                            try connectionViewModel.completeConnection(to: targetPoint)
                            return
                        } catch {
                            triggerErrorFeedback()
                        }
                    } else {
                        triggerErrorFeedback()
                    }
                }

                connectionViewModel.cancelConnection()
            }
    }

    private func triggerErrorFeedback() {
        withAnimation(.default.repeatCount(3, autoreverses: true)) {
            showConnectionError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showConnectionError = false
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            PortView(
                port: PortDefinition(id: "string", label: "Text", dataType: .string),
                isOutput: false,
                nodeId: nil,
                canvasState: nil,
                connectionViewModel: nil
            )

            PortView(
                port: PortDefinition(id: "image", label: "Image", dataType: .image),
                isOutput: true,
                nodeId: nil,
                canvasState: nil,
                connectionViewModel: nil
            )

            PortView(
                port: PortDefinition(id: "audio", label: "Audio", dataType: .audio),
                isOutput: false,
                nodeId: nil,
                canvasState: nil,
                connectionViewModel: nil
            )
        }
        .padding()
        .background(Color(white: 0.15, opacity: 0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
