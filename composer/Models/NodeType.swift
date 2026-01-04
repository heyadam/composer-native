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
    case textGeneration
    case previewOutput

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .textInput: return "Text Input"
        case .textGeneration: return "Text Generation"
        case .previewOutput: return "Preview Output"
        }
    }

    /// SF Symbol icon for the node
    var icon: String {
        switch self {
        case .textInput: return "text.alignleft"
        case .textGeneration: return "sparkles"
        case .previewOutput: return "eye"
        }
    }
}
