//
//  NodeFrame.swift
//  composer
//
//  Liquid Glass node chrome with header and ports
//

import SwiftUI

/// Status indicator for nodes
enum NodeStatus {
    case idle
    case running
    case success
    case error

    var color: Color {
        switch self {
        case .idle: return .secondary
        case .running: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
    
    var glassConfig: Glass {
        switch self {
        case .idle: return .regular
        case .running: return .regular.tint(.blue)
        case .success: return .regular.tint(.green)
        case .error: return .regular.tint(.red)
        }
    }
}

struct NodeFrame<Content: View>: View {
    let icon: String
    let title: String
    let status: NodeStatus?
    let inputPorts: [PortDefinition]
    let outputPorts: [PortDefinition]
    let nodeId: UUID?
    let canvasState: CanvasState?
    let connectionViewModel: ConnectionViewModel?
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        title: String,
        status: NodeStatus? = nil,
        inputPorts: [PortDefinition] = [],
        outputPorts: [PortDefinition] = [],
        nodeId: UUID? = nil,
        canvasState: CanvasState? = nil,
        connectionViewModel: ConnectionViewModel? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.status = status
        self.inputPorts = inputPorts
        self.outputPorts = outputPorts
        self.nodeId = nodeId
        self.canvasState = canvasState
        self.connectionViewModel = connectionViewModel
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Liquid Glass effect
            HStack(spacing: 10) {
                // Icon with glass background
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let status {
                    StatusBadge(status: status)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                // Header with subtle glass tint
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.5))
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Ports row
            if !inputPorts.isEmpty || !outputPorts.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    // Input ports (left side)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(inputPorts) { port in
                            PortView(
                                port: port,
                                isOutput: false,
                                nodeId: nodeId,
                                canvasState: canvasState,
                                connectionViewModel: connectionViewModel
                            )
                        }
                    }

                    Spacer()

                    // Output ports (right side)
                    VStack(alignment: .trailing, spacing: 10) {
                        ForEach(outputPorts) { port in
                            PortView(
                                port: port,
                                isOutput: true,
                                nodeId: nodeId,
                                canvasState: canvasState,
                                connectionViewModel: connectionViewModel
                            )
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }

            // Content with enhanced padding
            content()
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(minWidth: 200, maxWidth: 300)
        .background {
            // Main Liquid Glass background
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16.0))
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: NodeStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(status.color)
            
            if status == .running {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .glassEffect(status.glassConfig, in: .capsule)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        NodeFrame(
            icon: "text.alignleft",
            title: "Text Input",
            status: .idle,
            inputPorts: [],
            outputPorts: [
                PortDefinition(id: "output", label: "Output", dataType: .string, isRequired: true)
            ]
        ) {
            Text("Content goes here")
                .foregroundStyle(.secondary)
        }
    }
}
