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
        case .idle: return .gray
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
}

struct NodeFrame<Content: View>: View {
    let icon: String
    let title: String
    let status: NodeStatus?
    let inputPorts: [PortDefinition]
    let outputPorts: [PortDefinition]
    let nodeId: UUID?
    let canvasState: CanvasState?
    let onPortDragStart: ((PortDefinition, Bool, CGPoint) -> Void)?
    let onPortDragUpdate: ((PortDefinition, Bool, CGPoint) -> Void)?
    let onPortDragEnd: ((PortDefinition, Bool, CGPoint) -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        title: String,
        status: NodeStatus? = nil,
        inputPorts: [PortDefinition] = [],
        outputPorts: [PortDefinition] = [],
        nodeId: UUID? = nil,
        canvasState: CanvasState? = nil,
        onPortDragStart: ((PortDefinition, Bool, CGPoint) -> Void)? = nil,
        onPortDragUpdate: ((PortDefinition, Bool, CGPoint) -> Void)? = nil,
        onPortDragEnd: ((PortDefinition, Bool, CGPoint) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.status = status
        self.inputPorts = inputPorts
        self.outputPorts = outputPorts
        self.nodeId = nodeId
        self.canvasState = canvasState
        self.onPortDragStart = onPortDragStart
        self.onPortDragUpdate = onPortDragUpdate
        self.onPortDragEnd = onPortDragEnd
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if let status {
                    StatusBadge(status: status)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Ports row
            if !inputPorts.isEmpty || !outputPorts.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    // Input ports (left side)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(inputPorts) { port in
                            PortView(
                                port: port,
                                isOutput: false,
                                nodeId: nodeId,
                                canvasState: canvasState,
                                onDragStart: { position in
                                    onPortDragStart?(port, false, position)
                                },
                                onDragUpdate: { position in
                                    onPortDragUpdate?(port, false, position)
                                },
                                onDragEnd: { position in
                                    onPortDragEnd?(port, false, position)
                                }
                            )
                        }
                    }

                    Spacer()

                    // Output ports (right side)
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(outputPorts) { port in
                            PortView(
                                port: port,
                                isOutput: true,
                                nodeId: nodeId,
                                canvasState: canvasState,
                                onDragStart: { position in
                                    onPortDragStart?(port, true, position)
                                },
                                onDragUpdate: { position in
                                    onPortDragUpdate?(port, true, position)
                                },
                                onDragEnd: { position in
                                    onPortDragEnd?(port, true, position)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            // Content
            content()
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(minWidth: 180, maxWidth: 280)
        .background {
            // Semi-transparent background (avoids _UIGravityWellEffectAnchorView issues with transforms)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.15, opacity: 0.85))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: NodeStatus

    var body: some View {
        Image(systemName: status.icon)
            .font(.system(size: 12))
            .foregroundStyle(status.color)
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
