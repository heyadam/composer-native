//
//  CanvasState.swift
//  composer
//
//  Observable canvas state for transform, selection, and editing
//

import Foundation
import SwiftUI

@MainActor @Observable
final class CanvasState {
    // MARK: - Transform Constraints

    static let minScale: CGFloat = 0.25
    static let maxScale: CGFloat = 2.0

    // MARK: - Transform State

    /// Canvas offset (pan)
    var offset: CGSize = .zero

    /// Canvas scale (zoom)
    private(set) var scale: CGFloat = 1.0

    // MARK: - Selection State

    /// Currently selected node IDs
    var selectedNodeIds: Set<UUID> = []

    /// Currently selected edge IDs
    var selectedEdgeIds: Set<UUID> = []

    // MARK: - Connection State

    /// Active connection point (port being dragged from)
    var activeConnection: ConnectionPoint?

    /// Current position of connection end during drag
    var connectionEndPosition: CGPoint?

    // MARK: - Port Position Registry

    /// Registered port positions (key: "nodeId:portId", value: screen position)
    var portPositions: [String: CGPoint] = [:]

    /// Registered port data types (key: "nodeId:portId", value: data type)
    var portDataTypes: [String: PortDataType] = [:]

    /// Register a port's screen position and data type
    func registerPort(nodeId: UUID, portId: String, isOutput: Bool, dataType: PortDataType, position: CGPoint) {
        let key = "\(nodeId):\(portId)"
        portPositions[key] = position
        portDataTypes[key] = dataType
    }

    /// Get the data type for a registered port
    func portDataType(nodeId: UUID, portId: String) -> PortDataType? {
        let key = "\(nodeId):\(portId)"
        return portDataTypes[key]
    }

    /// Find a port near the given screen position
    func findPort(near position: CGPoint, excludingNode: UUID?, hitRadius: CGFloat = 20) -> (nodeId: UUID, portId: String)? {
        for (key, portPos) in portPositions {
            let distance = hypot(position.x - portPos.x, position.y - portPos.y)
            if distance <= hitRadius {
                let parts = key.split(separator: ":")
                guard parts.count == 2,
                      let nodeId = UUID(uuidString: String(parts[0])) else { continue }
                let portId = String(parts[1])

                // Skip if it's the excluded node (can't connect to self)
                if let excludingNode, nodeId == excludingNode {
                    continue
                }

                return (nodeId, portId)
            }
        }
        return nil
    }

    // MARK: - Editing State

    /// Whether a node is currently in edit mode (e.g., TextEditor focused)
    /// When true, canvas pan/zoom gestures are disabled
    var isEditingNode: Bool = false

    // MARK: - Canvas Size

    /// Canvas size (set via preference key, not in body)
    private(set) var canvasSize: CGSize = .zero

    // MARK: - Zoom Methods

    /// Update scale with clamping, anchored to a point in canvas coordinates
    func zoom(to newScale: CGFloat, anchor: CGPoint) {
        let clampedScale = min(max(newScale, Self.minScale), Self.maxScale)
        guard clampedScale != scale else { return }

        // Adjust offset so anchor point stays fixed on screen
        let scaleDelta = clampedScale / scale
        offset.width = anchor.x - (anchor.x - offset.width) * scaleDelta
        offset.height = anchor.y - (anchor.y - offset.height) * scaleDelta
        scale = clampedScale
    }

    /// Update canvas size (called from preference change)
    func updateCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    // MARK: - Coordinate Conversions

    /// Convert screen/canvas coordinates to world coordinates
    func canvasToWorld(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - offset.width) / scale,
            y: (point.y - offset.height) / scale
        )
    }

    /// Convert world coordinates to screen/canvas coordinates
    func worldToCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale + offset.width,
            y: point.y * scale + offset.height
        )
    }

    // MARK: - Selection Helpers

    /// Select a single node (clears other selections)
    func selectNode(_ nodeId: UUID) {
        selectedNodeIds = [nodeId]
        selectedEdgeIds.removeAll()
    }

    /// Toggle node selection (for multi-select)
    func toggleNodeSelection(_ nodeId: UUID) {
        if selectedNodeIds.contains(nodeId) {
            selectedNodeIds.remove(nodeId)
        } else {
            selectedNodeIds.insert(nodeId)
            selectedEdgeIds.removeAll()  // Edges can't be selected with nodes
        }
    }

    /// Select a single edge (clears other selections)
    func selectEdge(_ edgeId: UUID) {
        selectedEdgeIds = [edgeId]
        selectedNodeIds.removeAll()
    }

    /// Clear all selections
    func clearSelection() {
        selectedNodeIds.removeAll()
        selectedEdgeIds.removeAll()
    }

    /// Check if a node is selected
    func isNodeSelected(_ nodeId: UUID) -> Bool {
        selectedNodeIds.contains(nodeId)
    }

    /// Check if an edge is selected
    func isEdgeSelected(_ edgeId: UUID) -> Bool {
        selectedEdgeIds.contains(edgeId)
    }
}

// MARK: - Preference Key for Canvas Size

struct CanvasSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
