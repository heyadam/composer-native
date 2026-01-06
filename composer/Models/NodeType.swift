//
//  NodeType.swift
//  composer
//
//  Node type enum for the flow canvas
//

import Foundation

/// Defines the available node types in the flow canvas
///
/// Node-specific details (displayName, icon, ports, etc.) are delegated to
/// `NodeRegistry` which looks up the appropriate `NodeDefinition`.
enum NodeType: String, Codable, CaseIterable, Sendable {
    case textInput
    case textGeneration
    case previewOutput

    /// Human-readable display name (delegated to NodeRegistry)
    var displayName: String {
        NodeRegistry.displayName(for: self)
    }

    /// SF Symbol icon for the node (delegated to NodeRegistry)
    var icon: String {
        NodeRegistry.icon(for: self)
    }
}
