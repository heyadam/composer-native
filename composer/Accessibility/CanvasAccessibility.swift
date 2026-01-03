//
//  CanvasAccessibility.swift
//  composer
//
//  Canvas-level accessibility with rotor navigation
//

import SwiftUI

/// Custom rotor for navigating nodes
struct NodeRotor: AccessibilityRotorContent {
    let nodes: [FlowNode]
    let onSelect: (FlowNode) -> Void

    var body: some AccessibilityRotorContent {
        ForEach(nodes) { node in
            AccessibilityRotorEntry(node.label, id: node.id) {
                onSelect(node)
            }
        }
    }
}

/// Custom rotor for navigating edges
struct EdgeRotor: AccessibilityRotorContent {
    let edges: [FlowEdge]
    let onSelect: (FlowEdge) -> Void

    var body: some AccessibilityRotorContent {
        ForEach(edges) { edge in
            let label = edgeLabel(for: edge)
            AccessibilityRotorEntry(label, id: edge.id) {
                onSelect(edge)
            }
        }
    }

    private func edgeLabel(for edge: FlowEdge) -> String {
        let sourceName = edge.sourceNode?.label ?? "Unknown"
        let targetName = edge.targetNode?.label ?? "Unknown"
        return "\(sourceName) to \(targetName)"
    }
}

/// Canvas accessibility modifier
struct CanvasAccessibilityModifier: ViewModifier {
    let flow: Flow
    let canvasState: CanvasState

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(canvasLabel)
            .accessibilityHint(Text("Use rotor to navigate nodes and connections"))
            .accessibilityRotor("Nodes") {
                NodeRotor(nodes: flow.nodes) { node in
                    canvasState.selectNode(node.id)
                    announceSelection(node)
                }
            }
            .accessibilityRotor("Connections") {
                EdgeRotor(edges: flow.edges) { edge in
                    canvasState.selectEdge(edge.id)
                    announceEdgeSelection(edge)
                }
            }
    }

    private var canvasLabel: Text {
        let nodeCount = flow.nodes.count
        let edgeCount = flow.edges.count
        let nodeText = nodeCount == 1 ? "1 node" : "\(nodeCount) nodes"
        let edgeText = edgeCount == 1 ? "1 connection" : "\(edgeCount) connections"
        return Text("Flow canvas: \(flow.name). \(nodeText), \(edgeText)")
    }

    private func announceSelection(_ node: FlowNode) {
        let announcement = "Selected \(node.nodeType.displayName) node: \(node.label)"
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested, userInfo: [.announcement: announcement])
        #endif
    }

    private func announceEdgeSelection(_ edge: FlowEdge) {
        let sourceName = edge.sourceNode?.label ?? "Unknown"
        let targetName = edge.targetNode?.label ?? "Unknown"
        let announcement = "Selected connection from \(sourceName) to \(targetName)"
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested, userInfo: [.announcement: announcement])
        #endif
    }
}

extension View {
    /// Apply canvas-level accessibility
    func canvasAccessibility(flow: Flow, state: CanvasState) -> some View {
        modifier(CanvasAccessibilityModifier(flow: flow, canvasState: state))
    }
}

// MARK: - Accessibility Announcements

/// Utility for accessibility announcements
enum AccessibilityAnnouncement {
    /// Announce node added
    static func nodeAdded(_ node: FlowNode) {
        post("Added \(node.nodeType.displayName) node")
    }

    /// Announce node deleted
    static func nodeDeleted(_ node: FlowNode) {
        post("Deleted \(node.nodeType.displayName) node: \(node.label)")
    }

    /// Announce connection created
    static func connectionCreated(from source: FlowNode, to target: FlowNode) {
        post("Connected \(source.label) to \(target.label)")
    }

    /// Announce connection deleted
    static func connectionDeleted() {
        post("Connection deleted")
    }

    /// Announce selection changed
    static func selectionChanged(count: Int) {
        if count == 0 {
            post("Selection cleared")
        } else if count == 1 {
            post("1 item selected")
        } else {
            post("\(count) items selected")
        }
    }

    private static func post(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested, userInfo: [.announcement: message])
        #endif
    }
}
