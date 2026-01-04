//
//  KeyboardDeletionTests.swift
//  composerTests
//
//  Tests for keyboard deletion functionality on macOS and iOS
//

import Testing
import Foundation
@testable import composer

@MainActor
struct KeyboardDeletionTests {

    // MARK: - Selection State for Deletion

    @Test func hasSelectionReturnsTrueWithSelectedNodes() {
        let state = CanvasState()
        let nodeId = UUID()

        #expect(!state.hasSelection, "Should have no selection initially")

        state.selectNode(nodeId)

        #expect(state.hasSelection, "Should have selection after selecting node")
    }

    @Test func hasSelectionReturnsTrueWithSelectedEdges() {
        let state = CanvasState()
        let edgeId = UUID()

        #expect(!state.hasSelection, "Should have no selection initially")

        state.selectEdge(edgeId)

        #expect(state.hasSelection, "Should have selection after selecting edge")
    }

    @Test func hasSelectionReturnsFalseAfterClear() {
        let state = CanvasState()
        let nodeId = UUID()

        state.selectNode(nodeId)
        #expect(state.hasSelection)

        state.clearSelection()

        #expect(!state.hasSelection, "Should have no selection after clear")
    }

    // MARK: - Editing State Guard

    @Test func isEditingNodeBlocksDeletion() {
        let state = CanvasState()
        let nodeId = UUID()

        state.selectNode(nodeId)
        state.isEditingNode = true

        // The deletion guard checks: !isEditingNode && hasSelection
        // When isEditingNode is true, deletion should be blocked
        let shouldAllowDeletion = !state.isEditingNode && state.hasSelection
        #expect(!shouldAllowDeletion, "Deletion should be blocked while editing")
    }

    @Test func deletionAllowedWhenNotEditing() {
        let state = CanvasState()
        let nodeId = UUID()

        state.selectNode(nodeId)
        state.isEditingNode = false

        let shouldAllowDeletion = !state.isEditingNode && state.hasSelection
        #expect(shouldAllowDeletion, "Deletion should be allowed when not editing")
    }

    // MARK: - Selection Count

    @Test func selectionCountTracksMultipleNodes() {
        let state = CanvasState()
        let node1 = UUID()
        let node2 = UUID()

        state.toggleNodeSelection(node1)
        state.toggleNodeSelection(node2)

        #expect(state.selectionCount == 2)
        #expect(state.selectedNodeIds.count == 2)
    }

    @Test func selectionCountIncludesBothNodesAndEdges() {
        let state = CanvasState()
        let nodeId = UUID()
        let edgeId = UUID()

        // Note: selectNode clears edges, selectEdge clears nodes
        // So we need to add them differently for this test
        state.selectedNodeIds.insert(nodeId)
        state.selectedEdgeIds.insert(edgeId)

        #expect(state.selectionCount == 2)
    }

    // MARK: - Selection Clear After Deletion

    @Test func selectedNodeIdsCanBeCleared() {
        let state = CanvasState()
        let node1 = UUID()
        let node2 = UUID()

        state.toggleNodeSelection(node1)
        state.toggleNodeSelection(node2)

        #expect(state.selectedNodeIds.count == 2)

        state.selectedNodeIds.removeAll()

        #expect(state.selectedNodeIds.isEmpty)
        #expect(!state.hasSelection)
    }

    @Test func selectedEdgeIdsCanBeCleared() {
        let state = CanvasState()
        let edge1 = UUID()

        state.selectEdge(edge1)

        #expect(state.selectedEdgeIds.count == 1)

        state.selectedEdgeIds.removeAll()

        #expect(state.selectedEdgeIds.isEmpty)
        #expect(!state.hasSelection)
    }

    // MARK: - Edge Selection

    @Test func selectEdgeClearsNodeSelection() {
        let state = CanvasState()
        let nodeId = UUID()
        let edgeId = UUID()

        state.selectNode(nodeId)
        #expect(state.isNodeSelected(nodeId))

        state.selectEdge(edgeId)

        #expect(!state.isNodeSelected(nodeId), "Node selection should be cleared")
        #expect(state.isEdgeSelected(edgeId))
    }

    @Test func selectNodeClearsEdgeSelection() {
        let state = CanvasState()
        let nodeId = UUID()
        let edgeId = UUID()

        state.selectEdge(edgeId)
        #expect(state.isEdgeSelected(edgeId))

        state.selectNode(nodeId)

        #expect(!state.isEdgeSelected(edgeId), "Edge selection should be cleared")
        #expect(state.isNodeSelected(nodeId))
    }

    // MARK: - iOS KeyboardDeleteHandler Pattern Tests
    //
    // These tests verify the closure-based deletion pattern used by
    // KeyboardDeleteHandler on iOS. The handler uses:
    //   canDelete: { !canvasState.isEditingNode && canvasState.hasSelection }
    //   onDelete: deleteSelected

    @Test func canDeleteClosureReturnsFalseWhenEditing() {
        let state = CanvasState()
        let nodeId = UUID()

        state.selectNode(nodeId)
        state.isEditingNode = true

        // Simulate the canDelete closure from KeyboardDeleteHandler
        let canDelete = { !state.isEditingNode && state.hasSelection }

        #expect(!canDelete(), "canDelete should return false when editing text")
    }

    @Test func canDeleteClosureReturnsFalseWhenNoSelection() {
        let state = CanvasState()
        state.isEditingNode = false

        let canDelete = { !state.isEditingNode && state.hasSelection }

        #expect(!canDelete(), "canDelete should return false when nothing selected")
    }

    @Test func canDeleteClosureReturnsTrueWhenValidDeletionState() {
        let state = CanvasState()
        let nodeId = UUID()

        state.selectNode(nodeId)
        state.isEditingNode = false

        let canDelete = { !state.isEditingNode && state.hasSelection }

        #expect(canDelete(), "canDelete should return true with selection and not editing")
    }

    @Test func onDeleteCallbackIsInvokedWhenCanDeleteIsTrue() {
        let state = CanvasState()
        let nodeId = UUID()
        var deleteWasCalled = false

        state.selectNode(nodeId)
        state.isEditingNode = false

        // Simulate the handler pattern
        let canDelete = { !state.isEditingNode && state.hasSelection }
        let onDelete = { deleteWasCalled = true }

        if canDelete() {
            onDelete()
        }

        #expect(deleteWasCalled, "onDelete should be called when canDelete returns true")
    }

    @Test func onDeleteCallbackIsNotInvokedWhenCanDeleteIsFalse() {
        let state = CanvasState()
        var deleteWasCalled = false

        // No selection
        state.isEditingNode = false

        let canDelete = { !state.isEditingNode && state.hasSelection }
        let onDelete = { deleteWasCalled = true }

        if canDelete() {
            onDelete()
        }

        #expect(!deleteWasCalled, "onDelete should not be called when canDelete returns false")
    }

    @Test func canDeleteRespondsToStateChanges() {
        let state = CanvasState()
        let nodeId = UUID()

        let canDelete = { !state.isEditingNode && state.hasSelection }

        // Initially: no selection, not editing -> false
        #expect(!canDelete())

        // Add selection -> true
        state.selectNode(nodeId)
        #expect(canDelete())

        // Start editing -> false
        state.isEditingNode = true
        #expect(!canDelete())

        // Stop editing -> true
        state.isEditingNode = false
        #expect(canDelete())

        // Clear selection -> false
        state.clearSelection()
        #expect(!canDelete())
    }
}
