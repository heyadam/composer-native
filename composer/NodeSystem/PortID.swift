//
//  PortID.swift
//  composer
//
//  Stable port ID constants for all node types
//
//  IMPORTANT: These IDs are persisted in FlowEdge.sourceHandle and .targetHandle.
//  Changing them will break existing flows. Add new IDs, never modify existing ones.
//

import Foundation

/// Stable port ID constants
///
/// Each node type has its own namespace to avoid collisions.
/// Format: `<node-type>.<direction>.<name>` or `<node-type>.<name>` for single ports.
enum PortID {
    // MARK: - TextInput

    /// TextInput's single output port
    static let textInputOutput = "text-input.output"

    // MARK: - TextGeneration

    /// TextGeneration prompt input
    static let textGenInputPrompt = "text-gen.input.prompt"

    /// TextGeneration system message input (optional)
    static let textGenInputSystem = "text-gen.input.system"

    /// TextGeneration output
    static let textGenOutput = "text-gen.output"

    // MARK: - PreviewOutput

    /// PreviewOutput string input
    static let previewInputString = "preview.input.string"

    /// PreviewOutput image input
    static let previewInputImage = "preview.input.image"

    /// PreviewOutput audio input
    static let previewInputAudio = "preview.input.audio"

    // MARK: - Future Node Types

    // Conditional node (future)
    // static let conditionalInput = "conditional.input"
    // static let conditionalTrue = "conditional.true"
    // static let conditionalFalse = "conditional.false"

    // HTTP Request node (future)
    // static let httpRequestUrl = "http.input.url"
    // static let httpRequestBody = "http.input.body"
    // static let httpRequestOutput = "http.output"
}
