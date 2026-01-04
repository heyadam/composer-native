//
//  KeyboardDeletionTests.swift
//  composerTests
//
//  Tests for keyboard deletion functionality on macOS
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
}
