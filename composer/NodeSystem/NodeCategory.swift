//
//  NodeCategory.swift
//  composer
//
//  Categories for organizing nodes in the node picker
//

import Foundation

/// Categories for organizing nodes in the picker UI
enum NodeCategory: String, CaseIterable, Sendable {
    case input = "Input"
    case llm = "LLM"
    case transform = "Transform"
    case controlFlow = "Control Flow"
    case integration = "Integration"
    case output = "Output"

    /// Human-readable display name
    var displayName: String {
        rawValue
    }

    /// SF Symbol icon for the category
    var icon: String {
        switch self {
        case .input: return "arrow.right.circle"
        case .llm: return "sparkles"
        case .transform: return "arrow.triangle.branch"
        case .controlFlow: return "arrow.triangle.swap"
        case .integration: return "network"
        case .output: return "arrow.left.circle"
        }
    }

    /// Sort order for display
    var sortOrder: Int {
        switch self {
        case .input: return 0
        case .llm: return 1
        case .transform: return 2
        case .controlFlow: return 3
        case .integration: return 4
        case .output: return 5
        }
    }
}
