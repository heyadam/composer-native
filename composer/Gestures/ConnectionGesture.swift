//
//  ConnectionGesture.swift
//  composer
//
//  Gesture for creating connections between ports
//

import SwiftUI

/// Creates a connection gesture for ports
/// Uses highPriorityGesture to win over node drag
struct ConnectionGestureModifier: ViewModifier {
    let port: PortDefinition
    let nodeId: UUID
    let isOutput: Bool
    let canvasState: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var isDragging = false
    @State private var showConnectionError = false

    func body(content: Content) -> some View {
        content
            .highPriorityGesture(connectionGesture)
            .modifier(ConnectionErrorModifier(showError: showConnectionError))
    }

    private var connectionGesture: some Gesture {
        DragGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                guard let connectionViewModel else { return }

                if !isDragging {
                    // Start connection
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

                // Update connection end position
                canvasState.connectionEndPosition = value.location
                connectionViewModel.updateConnection(to: value.location)
            }
            .onEnded { value in
                defer {
                    canvasState.activeConnection = nil
                    canvasState.connectionEndPosition = nil
                    isDragging = false
                }

                guard let connectionViewModel else { return }

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
                            // Show error feedback
                            triggerErrorFeedback()
                        }
                    } else {
                        // Incompatible connection - show error feedback
                        triggerErrorFeedback()
                    }
                }

                // No valid port found or connection failed, cancel the connection
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

/// Shows a shake animation when connection fails
struct ConnectionErrorModifier: ViewModifier {
    let showError: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: showError ? -4 : 0)
    }
}

extension View {
    /// Apply connection gesture for ports
    func connectionGesture(
        port: PortDefinition,
        nodeId: UUID,
        isOutput: Bool,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> some View {
        modifier(ConnectionGestureModifier(
            port: port,
            nodeId: nodeId,
            isOutput: isOutput,
            canvasState: state,
            connectionViewModel: connectionViewModel
        ))
    }
}
