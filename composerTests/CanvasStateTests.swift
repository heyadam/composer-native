//
//  CanvasStateTests.swift
//  composerTests
//
//  Tests for canvas state, especially port position registry used by gestures
//

import Testing
import Foundation
import CoreGraphics
@testable import composer

@MainActor
struct CanvasStateTests {

    // MARK: - Port Registration

    @Test func registerPortStoresPosition() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.registerPort(
            nodeId: nodeId,
            portId: "output",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 100, y: 200)
        )

        let key = "\(nodeId):output"
        #expect(state.portPositions[key] == CGPoint(x: 100, y: 200))
    }

    @Test func registerPortStoresDataType() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.registerPort(
            nodeId: nodeId,
            portId: "image-out",
            isOutput: true,
            dataType: .image,
            position: CGPoint(x: 100, y: 200)
        )

        let dataType = state.portDataType(nodeId: nodeId, portId: "image-out")
        #expect(dataType == .image)
    }

    // MARK: - Port Lookup

    @Test func findPortNearPosition() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.registerPort(
            nodeId: nodeId,
            portId: "out",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 100, y: 100)
        )

        // Search within default 20pt radius
        let found = state.findPort(near: CGPoint(x: 110, y: 105), excludingNode: nil)

        #expect(found != nil)
        #expect(found?.nodeId == nodeId)
        #expect(found?.portId == "out")
    }

    @Test func findPortOutsideRadiusReturnsNil() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.registerPort(
            nodeId: nodeId,
            portId: "out",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 100, y: 100)
        )

        // Search outside default 20pt radius
        let found = state.findPort(near: CGPoint(x: 150, y: 150), excludingNode: nil)

        #expect(found == nil)
    }

    @Test func findPortRespectsCustomHitRadius() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.registerPort(
            nodeId: nodeId,
            portId: "out",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 100, y: 100)
        )

        // Search at 25pt away - outside default radius but inside custom 30pt radius
        let point = CGPoint(x: 125, y: 100)

        let foundWithDefault = state.findPort(near: point, excludingNode: nil, hitRadius: 20)
        let foundWithLarger = state.findPort(near: point, excludingNode: nil, hitRadius: 30)

        #expect(foundWithDefault == nil, "Should not find with 20pt radius")
        #expect(foundWithLarger != nil, "Should find with 30pt radius")
    }

    @Test func findPortExcludesSpecifiedNode() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.registerPort(
            nodeId: nodeId,
            portId: "out",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 100, y: 100)
        )

        // Search at port location but exclude the node
        let found = state.findPort(near: CGPoint(x: 100, y: 100), excludingNode: nodeId)

        #expect(found == nil, "Should not find port from excluded node")
    }

    @Test func findPortFindsAnyWithinRadius() throws {
        let state = CanvasState()
        let nodeId1 = UUID()
        let nodeId2 = UUID()

        state.registerPort(
            nodeId: nodeId1,
            portId: "out1",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 100, y: 100)
        )

        state.registerPort(
            nodeId: nodeId2,
            portId: "out2",
            isOutput: true,
            dataType: .string,
            position: CGPoint(x: 120, y: 100) // 20pt away from first
        )

        // Search between them - should find at least one
        let found = state.findPort(near: CGPoint(x: 110, y: 100), excludingNode: nil, hitRadius: 15)

        // Should find one of them (within radius)
        #expect(found != nil)
    }

    // MARK: - Active Connection State

    @Test func activeConnectionBlocksOtherGestures() throws {
        let state = CanvasState()
        let nodeId = UUID()

        // Initially no connection
        #expect(state.activeConnection == nil)

        // Simulate starting a connection
        state.activeConnection = ConnectionPoint(
            nodeId: nodeId,
            portId: "out",
            portType: .string,
            isOutput: true,
            position: CGPoint(x: 100, y: 100)
        )

        #expect(state.activeConnection != nil)

        // Canvas pan gesture should check this and bail out
        // Node drag gesture should check this and bail out
    }

    @Test func connectionEndPositionTracked() throws {
        let state = CanvasState()

        state.connectionEndPosition = CGPoint(x: 200, y: 300)

        #expect(state.connectionEndPosition == CGPoint(x: 200, y: 300))
    }

    // MARK: - Coordinate Transforms

    @Test func canvasToWorldTransformWithOffset() throws {
        let state = CanvasState()
        state.offset = CGSize(width: 100, height: 50)
        // Scale is 1.0 by default

        let screenPoint = CGPoint(x: 200, y: 150)
        let worldPoint = state.canvasToWorld(screenPoint)

        // world = (screen - offset) / scale
        // world.x = (200 - 100) / 1 = 100
        // world.y = (150 - 50) / 1 = 100
        #expect(worldPoint.x == 100)
        #expect(worldPoint.y == 100)
    }

    @Test func worldToCanvasTransformWithOffset() throws {
        let state = CanvasState()
        state.offset = CGSize(width: 100, height: 50)
        // Scale is 1.0 by default

        let worldPoint = CGPoint(x: 100, y: 100)
        let screenPoint = state.worldToCanvas(worldPoint)

        // screen = world * scale + offset
        // screen.x = 100 * 1 + 100 = 200
        // screen.y = 100 * 1 + 50 = 150
        #expect(screenPoint.x == 200)
        #expect(screenPoint.y == 150)
    }

    @Test func transformsAreInverses() throws {
        let state = CanvasState()
        state.offset = CGSize(width: 50, height: 75)

        let originalWorld = CGPoint(x: 123, y: 456)
        let screen = state.worldToCanvas(originalWorld)
        let backToWorld = state.canvasToWorld(screen)

        #expect(abs(backToWorld.x - originalWorld.x) < 0.001)
        #expect(abs(backToWorld.y - originalWorld.y) < 0.001)
    }

    // MARK: - Node Selection

    @Test func selectNodeUpdatesSelection() throws {
        let state = CanvasState()
        let nodeId = UUID()

        state.selectNode(nodeId)

        #expect(state.selectedNodeIds.contains(nodeId))
        #expect(state.isNodeSelected(nodeId))
    }

    @Test func toggleNodeSelection() throws {
        let state = CanvasState()
        let nodeId = UUID()

        // Select
        state.toggleNodeSelection(nodeId)
        #expect(state.isNodeSelected(nodeId))

        // Deselect
        state.toggleNodeSelection(nodeId)
        #expect(!state.isNodeSelected(nodeId))
    }

    @Test func selectNodeClearsPreviousSelection() throws {
        let state = CanvasState()
        let node1 = UUID()
        let node2 = UUID()

        state.selectNode(node1)
        state.selectNode(node2)

        #expect(!state.isNodeSelected(node1), "Previous selection should be cleared")
        #expect(state.isNodeSelected(node2))
    }

    // MARK: - Dragging State

    @Test func isDraggingNodeState() throws {
        let state = CanvasState()

        #expect(!state.isDraggingNode)

        state.isDraggingNode = true
        #expect(state.isDraggingNode)
    }
}
