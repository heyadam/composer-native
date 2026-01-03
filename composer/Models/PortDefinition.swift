//
//  PortDefinition.swift
//  composer
//
//  Port types, colors, and definitions
//

import SwiftUI

/// Data types that can flow through ports
enum PortDataType: String, Codable, CaseIterable, Sendable {
    case string
    case image
    case audio
    case pulse

    /// Port color matching web app CSS variables
    var color: Color {
        switch self {
        case .string: return Color(red: 0.56, green: 0.78, blue: 0.96)  // Soft azure
        case .image:  return Color(red: 0.79, green: 0.72, blue: 0.98)  // Lavender
        case .audio:  return Color(red: 0.56, green: 0.96, blue: 0.89)  // Electric mint
        case .pulse:  return Color(red: 0.96, green: 0.78, blue: 0.56)  // Apricot
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .string: return "String"
        case .image: return "Image"
        case .audio: return "Audio"
        case .pulse: return "Pulse"
        }
    }
}

/// Defines a single port on a node
struct PortDefinition: Identifiable, Sendable {
    let id: String
    let label: String
    let dataType: PortDataType
    let isRequired: Bool

    init(id: String, label: String, dataType: PortDataType, isRequired: Bool = false) {
        self.id = id
        self.label = label
        self.dataType = dataType
        self.isRequired = isRequired
    }
}

/// Color scheme for ports - can be customized via Environment
struct PortColorScheme: Sendable {
    var string: Color = PortDataType.string.color
    var image: Color = PortDataType.image.color
    var audio: Color = PortDataType.audio.color
    var pulse: Color = PortDataType.pulse.color

    func color(for dataType: PortDataType) -> Color {
        switch dataType {
        case .string: return string
        case .image: return image
        case .audio: return audio
        case .pulse: return pulse
        }
    }
}

/// Environment key for port colors
extension EnvironmentValues {
    @Entry var portColors: PortColorScheme = PortColorScheme()
}
