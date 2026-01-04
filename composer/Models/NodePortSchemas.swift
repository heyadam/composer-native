//
//  NodePortSchemas.swift
//  composer
//
//  Port definitions per node type with stable IDs
//

import Foundation

/// Stable port IDs - these must never change to preserve edge references
enum PortID {
    // TextInput ports
    static let textInputOutput = "text-input.output"

    // TextGeneration ports
    static let textGenInputPrompt = "text-gen.input.prompt"
    static let textGenInputSystem = "text-gen.input.system"
    static let textGenOutput = "text-gen.output"

    // PreviewOutput ports
    static let previewInputString = "preview.input.string"
    static let previewInputImage = "preview.input.image"
    static let previewInputAudio = "preview.input.audio"
}

/// Port schema definitions for each node type
enum NodePortSchemas {
    /// Get input ports for a node type
    static func inputPorts(for type: NodeType) -> [PortDefinition] {
        switch type {
        case .textInput:
            return []
        case .textGeneration:
            return [
                PortDefinition(id: PortID.textGenInputPrompt, label: "Prompt", dataType: .string, isRequired: true),
                PortDefinition(id: PortID.textGenInputSystem, label: "System", dataType: .string, isRequired: false),
            ]
        case .previewOutput:
            return [
                PortDefinition(id: PortID.previewInputString, label: "Text", dataType: .string, isRequired: false),
                PortDefinition(id: PortID.previewInputImage, label: "Image", dataType: .image, isRequired: false),
                PortDefinition(id: PortID.previewInputAudio, label: "Audio", dataType: .audio, isRequired: false),
            ]
        }
    }

    /// Get output ports for a node type
    static func outputPorts(for type: NodeType) -> [PortDefinition] {
        switch type {
        case .textInput:
            return [
                PortDefinition(id: PortID.textInputOutput, label: "Output", dataType: .string, isRequired: true)
            ]
        case .textGeneration:
            return [
                PortDefinition(id: PortID.textGenOutput, label: "Output", dataType: .string, isRequired: false)
            ]
        case .previewOutput:
            return []
        }
    }

    /// Check if two ports can be connected
    static func canConnect(sourceType: PortDataType, targetType: PortDataType) -> Bool {
        // For now, only same types can connect
        // This can be expanded for type coercion later
        return sourceType == targetType
    }
}
