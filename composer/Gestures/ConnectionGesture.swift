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
    let onConnectionComplete: ((ConnectionPoint) -> Void)?

    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .highPriorityGesture(connectionGesture)
    }

    private var connectionGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                guard let connectionViewModel else { return }

                if !isDragging {
                    // Start connection
                    isDragging = true

                    let sourcePoint = ConnectionPoint(
                        nodeId: nodeId,
                        portId: port.id,
                        portType: port.dataType,
                        isOutput: isOutput,
                        position: canvasState.canvasToWorld(value.startLocation)
                    )

                    connectionViewModel.beginConnection(from: sourcePoint)
                    canvasState.activeConnection = sourcePoint
                }

                // Update connection end position
                canvasState.connectionEndPosition = value.location
                connectionViewModel.updateConnection(to: value.location)
            }
            .onEnded { value in
                guard let connectionViewModel else { return }

                // Check if we're over a compatible port
                // This would use hit testing to find target port
                // For now, just cancel

                connectionViewModel.cancelConnection()
                canvasState.activeConnection = nil
                canvasState.connectionEndPosition = nil
                isDragging = false
            }
    }
}

extension View {
    /// Apply connection gesture for ports
    func connectionGesture(
        port: PortDefinition,
        nodeId: UUID,
        isOutput: Bool,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?,
        onComplete: ((ConnectionPoint) -> Void)? = nil
    ) -> some View {
        modifier(ConnectionGestureModifier(
            port: port,
            nodeId: nodeId,
            isOutput: isOutput,
            canvasState: state,
            connectionViewModel: connectionViewModel,
            onConnectionComplete: onComplete
        ))
    }
}
