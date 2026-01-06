//
//  ConnectionViewModel.swift
//  composer
//
//  Manages connection creation state and validation
//

import Foundation
import SwiftUI

@MainActor @Observable
final class ConnectionViewModel {
    private weak var canvasViewModel: FlowCanvasViewModel?
    private weak var canvasState: CanvasState?

    /// The active connection point being dragged from
    private(set) var sourcePoint: ConnectionPoint?

    /// Current position of the connection end (cursor/finger)
    var connectionEndPosition: CGPoint?

    /// Whether a connection is currently being created
    var isConnecting: Bool {
        sourcePoint != nil
    }

    init(canvasViewModel: FlowCanvasViewModel?, canvasState: CanvasState?) {
        self.canvasViewModel = canvasViewModel
        self.canvasState = canvasState
    }

    /// Begin connection from a port
    func beginConnection(from point: ConnectionPoint) {
        sourcePoint = point
        connectionEndPosition = point.position
    }

    /// Update connection end position during drag
    func updateConnection(to position: CGPoint) {
        connectionEndPosition = position
    }

    /// Cancel the current connection
    func cancelConnection() {
        sourcePoint = nil
        connectionEndPosition = nil
    }

    /// Attempt to complete connection to a target port
    func completeConnection(to target: ConnectionPoint) throws {
        guard let source = sourcePoint,
              let canvasViewModel else {
            cancelConnection()
            return
        }

        // Determine which is source and which is target
        let (actualSource, actualTarget): (ConnectionPoint, ConnectionPoint)
        if source.isOutput {
            actualSource = source
            actualTarget = target
        } else {
            actualSource = target
            actualTarget = source
        }

        try canvasViewModel.createEdge(from: actualSource, to: actualTarget)
        cancelConnection()
    }

    /// Check if a port can be connected to the current source
    func canConnect(to port: ConnectionPoint) -> Bool {
        guard let source = sourcePoint else { return false }

        // Can't connect to same node
        guard source.nodeId != port.nodeId else { return false }

        // Must be opposite directions (output to input or vice versa)
        guard source.isOutput != port.isOutput else { return false }

        // Check type compatibility (delegated to NodeRegistry)
        return NodeRegistry.canConnect(
            sourceType: source.isOutput ? source.portType : port.portType,
            targetType: source.isOutput ? port.portType : source.portType
        )
    }

    /// Get all compatible ports for the current source
    func compatiblePorts(in nodes: [FlowNode]) -> [ConnectionPoint] {
        guard let source = sourcePoint else { return [] }

        var compatible: [ConnectionPoint] = []

        for node in nodes {
            guard node.id != source.nodeId else { continue }

            // If source is output, find compatible inputs
            // If source is input, find compatible outputs
            let ports = source.isOutput ? node.inputPorts : node.outputPorts

            for port in ports {
                let canConnect = source.isOutput
                    ? NodeRegistry.canConnect(sourceType: source.portType, targetType: port.dataType)
                    : NodeRegistry.canConnect(sourceType: port.dataType, targetType: source.portType)

                if canConnect {
                    compatible.append(ConnectionPoint(
                        nodeId: node.id,
                        portId: port.id,
                        portType: port.dataType,
                        isOutput: !source.isOutput
                    ))
                }
            }
        }

        return compatible
    }
}
