//
//  NodeViewModel.swift
//  composer
//
//  Wraps FlowNode with transient state for UI
//

import Foundation
import SwiftUI

@MainActor @Observable
final class NodeViewModel {
    let node: FlowNode
    private weak var canvasViewModel: FlowCanvasViewModel?

    /// Measured size (not persisted, updated via onGeometryChange)
    var measuredSize: CGSize = CGSize(width: 200, height: 100)

    /// Whether this node is currently selected
    var isSelected: Bool = false

    /// Whether this node is in editing mode (e.g., TextEditor focused)
    var isEditing: Bool = false

    init(node: FlowNode, canvasViewModel: FlowCanvasViewModel?) {
        self.node = node
        self.canvasViewModel = canvasViewModel
    }

    /// Current display position (transient during drag, or persisted)
    var displayPosition: CGPoint {
        canvasViewModel?.displayPosition(for: node.id) ?? node.position
    }

    /// Node type for convenience
    var nodeType: NodeType {
        node.nodeType
    }

    /// Input ports for this node
    var inputPorts: [PortDefinition] {
        node.inputPorts
    }

    /// Output ports for this node
    var outputPorts: [PortDefinition] {
        node.outputPorts
    }

    /// Update measured size when geometry changes
    func updateMeasuredSize(_ size: CGSize) {
        measuredSize = size
    }

    /// Begin editing this node
    func beginEditing() {
        isEditing = true
    }

    /// End editing this node
    func endEditing() {
        isEditing = false
    }

    /// Get text content for TextInput nodes
    var textContent: String {
        get {
            node.decodeData(TextInputNodeData.self)?.text ?? ""
        }
        set {
            node.encodeData(TextInputNodeData(text: newValue))
            // Signal SwiftData that the flow changed - critical for iPad where
            // view recreation can cause stale object references
            node.flow?.touch()
        }
    }
}
