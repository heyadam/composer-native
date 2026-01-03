//
//  NodeType.swift
//  composer
//
//  Node type enum for the flow canvas
//

import Foundation

/// Defines the available node types in the flow canvas
enum NodeType: String, Codable, CaseIterable, Sendable {
    case textInput
    case previewOutput

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .textInput: return "Text Input"
        case .previewOutput: return "Preview Output"
        }
    }

    /// SF Symbol icon for the node
    var icon: String {
        switch self {
        case .textInput: return "text.alignleft"
        case .previewOutput: return "eye"
        }
    }
}
