//
//  HitTesterTests.swift
//  composerTests
//
//  Tests for hit testing logic to ensure gesture priority works correctly
//

import Testing
import Foundation
import CoreGraphics
@testable import composer

struct HitTesterTests {

    // MARK: - Port Hit Testing

    @Test func portHitTestHasHighestPriority() throws {
        // Create a node with ports
        let node = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // Hit test at an output port location (right side of node)
        // Ports are at x = node.x + nodeWidth, y = node.y + 30 * (index + 1)
        let portPoint = CGPoint(x: 300, y: 130) // Output port area

        let result = hitTester.hitTest(portPoint) { $0 } // Identity transform

        // Should hit the port, not the node
        if case .port(let nodeId, _, let isOutput) = result {
            #expect(nodeId == node.id)
            #expect(isOutput == true)
        } else {
            Issue.record("Expected port hit, got \(result)")
        }
    }

    @Test func portHitWithin22PointRadius() throws {
        let node = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // Port is at approximately (300, 130) for output port
        // Test at 20 points away - should still hit
        let nearPoint = CGPoint(x: 300, y: 150) // 20 points below port center

        let result = hitTester.hitTest(nearPoint) { $0 }

        if case .port = result {
            // Good - within radius
        } else {
            Issue.record("Expected port hit within 22pt radius, got \(result)")
        }
    }

    @Test func inputPortHitTesting() throws {
        let node = FlowNode(
            nodeType: .textGeneration, // Has input ports
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // Input ports are on the left side (x = node.x)
        let inputPortPoint = CGPoint(x: 100, y: 130)

        let result = hitTester.hitTest(inputPortPoint) { $0 }

        if case .port(let nodeId, _, let isOutput) = result {
            #expect(nodeId == node.id)
            #expect(isOutput == false, "Should be input port")
        } else {
            Issue.record("Expected input port hit, got \(result)")
        }
    }

    // MARK: - Node Hit Testing

    @Test func nodeHitWhenNotOnPort() throws {
        let node = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // Hit in the middle of the node (not near ports)
        let centerPoint = CGPoint(x: 200, y: 150)

        let result = hitTester.hitTest(centerPoint) { $0 }

        if case .node(let nodeId) = result {
            #expect(nodeId == node.id)
        } else {
            Issue.record("Expected node hit, got \(result)")
        }
    }

    @Test func topmostNodeWinsOnOverlap() throws {
        // Create overlapping nodes
        let bottomNode = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )
        let topNode = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 150, y: 120) // Overlaps with bottom
        )

        // Nodes array order matters - last is topmost (reversed in hit test)
        let hitTester = HitTester(nodes: [bottomNode, topNode], edges: [])

        // Hit in overlap area
        let overlapPoint = CGPoint(x: 200, y: 150)

        let result = hitTester.hitTest(overlapPoint) { $0 }

        if case .node(let nodeId) = result {
            #expect(nodeId == topNode.id, "Topmost node should win")
        } else {
            Issue.record("Expected node hit, got \(result)")
        }
    }

    // MARK: - Canvas Hit Testing

    @Test func canvasHitWhenNothingElseHit() throws {
        let node = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // Hit far from any node
        let emptyPoint = CGPoint(x: 500, y: 500)

        let result = hitTester.hitTest(emptyPoint) { $0 }

        #expect(result == .canvas)
    }

    @Test func canvasHitWithNoNodes() throws {
        let hitTester = HitTester(nodes: [], edges: [])

        let result = hitTester.hitTest(CGPoint(x: 100, y: 100)) { $0 }

        #expect(result == .canvas)
    }

    // MARK: - Coordinate Transform

    @Test func hitTestRespectsTransform() throws {
        // Node at world position (100, 100) with default size ~200x100
        let node = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // With identity transform, screen point maps directly to world
        // Point inside the node (node is at 100,100 with size ~200x100)
        let screenPoint = CGPoint(x: 150, y: 130)

        let result = hitTester.hitTest(screenPoint) { $0 } // Identity

        if case .node(let nodeId) = result {
            #expect(nodeId == node.id)
        } else {
            Issue.record("Expected node hit with identity transform, got \(result)")
        }
    }

    @Test func hitTestWithScaleTransform() throws {
        // Node at world position (100, 100)
        let node = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 100)
        )

        let hitTester = HitTester(nodes: [node], edges: [])

        // Screen point that transforms to inside the node
        // If world = screen / 2, then screen (300, 300) -> world (150, 150) which is inside node
        let screenPoint = CGPoint(x: 300, y: 300)

        let result = hitTester.hitTest(screenPoint) { pt in
            CGPoint(x: pt.x / 2, y: pt.y / 2)
        }

        if case .node(let nodeId) = result {
            #expect(nodeId == node.id)
        } else {
            Issue.record("Expected node hit with scale transform, got \(result)")
        }
    }
}
