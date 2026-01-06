//
//  PreviewSidebarState.swift
//  composer
//
//  Observable state management for the preview sidebar
//

import Foundation
import SwiftUI

/// State management for the preview sidebar
@MainActor @Observable
final class PreviewSidebarState {
    /// Whether the sidebar is visible
    var isVisible: Bool = false

    /// Preview entries from PreviewOutput nodes
    var previewEntries: [PreviewEntry] = []

    /// Current width of the sidebar (persisted via @AppStorage in view)
    var width: CGFloat = 340

    /// Minimum sidebar width
    static let minWidth: CGFloat = 240

    /// Maximum sidebar width
    static let maxWidth: CGFloat = 600

    /// Toggle sidebar visibility
    func toggle() {
        isVisible.toggle()
    }

    /// Show the sidebar
    func show() {
        isVisible = true
    }

    /// Hide the sidebar
    func hide() {
        isVisible = false
    }

    /// Clear all preview entries
    func clearEntries() {
        previewEntries.removeAll()
    }

    /// Add or update a preview entry by node ID
    ///
    /// If an entry for this node already exists, it will be replaced.
    /// Otherwise, a new entry is appended.
    func addOrUpdatePreviewEntry(_ entry: PreviewEntry) {
        if let idx = previewEntries.firstIndex(where: { $0.nodeId == entry.nodeId }) {
            previewEntries[idx] = entry
        } else {
            previewEntries.append(entry)
        }
    }

    /// Update status for a preview entry by node ID
    func updateStatus(for nodeId: UUID, status: ExecutionStatus, error: String? = nil) {
        if let idx = previewEntries.firstIndex(where: { $0.nodeId == nodeId }) {
            previewEntries[idx].status = status
            previewEntries[idx].error = error
            previewEntries[idx].timestamp = Date()
        }
    }

    /// Get preview entry for a node
    func entry(for nodeId: UUID) -> PreviewEntry? {
        previewEntries.first { $0.nodeId == nodeId }
    }
}
