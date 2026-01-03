//
//  NodeAccessibility.swift
//  composer
//
//  VoiceOver support for nodes
//

import SwiftUI

/// Accessibility extensions for node views
extension View {
    /// Apply standard node accessibility
    func nodeAccessibility(
        node: FlowNode,
        isSelected: Bool,
        onDelete: @escaping () -> Void,
        onBeginConnection: @escaping () -> Void
    ) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(nodeAccessibilityLabel(for: node))
            .accessibilityHint(nodeAccessibilityHint(isSelected: isSelected))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityAction(named: "Delete") {
                onDelete()
            }
            .accessibilityAction(named: "Connect Output") {
                onBeginConnection()
            }
    }

    private func nodeAccessibilityLabel(for node: FlowNode) -> Text {
        let connectionCount = node.incomingEdges.count + node.outgoingEdges.count
        let connectionText = connectionCount == 1 ? "1 connection" : "\(connectionCount) connections"

        return Text("\(node.nodeType.displayName) node: \(node.label). \(connectionText)")
    }

    private func nodeAccessibilityHint(isSelected: Bool) -> Text {
        if isSelected {
            return Text("Selected. Double tap to edit. Swipe up or down for actions.")
        } else {
            return Text("Double tap to select")
        }
    }
}

/// Accessibility extensions for ports
extension View {
    /// Apply standard port accessibility
    func portAccessibility(
        port: PortDefinition,
        isOutput: Bool,
        isConnected: Bool
    ) -> some View {
        self
            .accessibilityLabel(portAccessibilityLabel(
                port: port,
                isOutput: isOutput,
                isConnected: isConnected
            ))
            .accessibilityHint(Text("Double tap and drag to connect"))
            .accessibilityAddTraits(.isButton)
    }

    private func portAccessibilityLabel(
        port: PortDefinition,
        isOutput: Bool,
        isConnected: Bool
    ) -> Text {
        let direction = isOutput ? "output" : "input"
        let connectionStatus = isConnected ? "connected" : "not connected"
        return Text("\(port.label) \(port.dataType.displayName) \(direction) port, \(connectionStatus)")
    }
}

/// Accessibility extensions for edges
extension View {
    /// Apply standard edge accessibility
    func edgeAccessibility(
        edge: FlowEdge,
        isSelected: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(edgeAccessibilityLabel(for: edge))
            .accessibilityHint(edgeAccessibilityHint(isSelected: isSelected))
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityAction(named: "Delete") {
                onDelete()
            }
    }

    private func edgeAccessibilityLabel(for edge: FlowEdge) -> Text {
        let sourceName = edge.sourceNode?.label ?? "Unknown"
        let targetName = edge.targetNode?.label ?? "Unknown"
        return Text("Connection from \(sourceName) to \(targetName), \(edge.dataType.displayName) type")
    }

    private func edgeAccessibilityHint(isSelected: Bool) -> Text {
        if isSelected {
            return Text("Selected. Swipe up or down for actions.")
        } else {
            return Text("Double tap to select")
        }
    }
}
