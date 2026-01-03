//
//  TextEditingCoordinator.swift
//  composer
//
//  Manages focus state for TextEditor in nodes
//

import Foundation
import SwiftUI

/// Coordinates text editing state across nodes
/// Ensures canvas gestures are disabled while editing
@MainActor @Observable
final class TextEditingCoordinator {
    /// Reference to canvas state for disabling gestures
    weak var canvasState: CanvasState?

    /// Currently editing node ID (if any)
    private(set) var editingNodeId: UUID?

    init(canvasState: CanvasState? = nil) {
        self.canvasState = canvasState
    }

    /// Begin editing a node
    func beginEditing(nodeId: UUID) {
        editingNodeId = nodeId
        canvasState?.isEditingNode = true
    }

    /// End editing
    func endEditing() {
        editingNodeId = nil
        canvasState?.isEditingNode = false
    }

    /// Check if a specific node is being edited
    func isEditing(nodeId: UUID) -> Bool {
        editingNodeId == nodeId
    }

    /// Check if any node is being edited
    var isEditing: Bool {
        editingNodeId != nil
    }
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var textEditingCoordinator: TextEditingCoordinator? = nil
}

// MARK: - View Modifier

struct TextEditingCoordinatorModifier: ViewModifier {
    let coordinator: TextEditingCoordinator

    func body(content: Content) -> some View {
        content
            .environment(\.textEditingCoordinator, coordinator)
    }
}

extension View {
    /// Inject text editing coordinator into environment
    func textEditingCoordinator(_ coordinator: TextEditingCoordinator) -> some View {
        modifier(TextEditingCoordinatorModifier(coordinator: coordinator))
    }
}
