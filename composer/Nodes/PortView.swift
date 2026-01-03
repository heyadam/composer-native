//
//  PortView.swift
//  composer
//
//  Port circles with connection gestures
//

import SwiftUI

struct PortView: View {
    let port: PortDefinition
    let isOutput: Bool
    let nodeId: UUID?
    let canvasState: CanvasState?
    let onDragStart: ((CGPoint) -> Void)?
    let onDragUpdate: ((CGPoint) -> Void)?
    let onDragEnd: ((CGPoint) -> Void)?

    @State private var isHovered = false
    @State private var isDragging = false

    /// Port circle size
    private let normalSize: CGFloat = 14
    private let hoverSize: CGFloat = 18

    /// Hit target for accessibility
    private let hitTargetSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 6) {
            if isOutput {
                portLabel
                portCircle
            } else {
                portCircle
                portLabel
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .highPriorityGesture(connectionDragGesture)
    }

    private var portLabel: some View {
        Text(port.label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var portCircle: some View {
        Circle()
            .fill(port.dataType.color)
            .frame(
                width: (isHovered || isDragging) ? hoverSize : normalSize,
                height: (isHovered || isDragging) ? hoverSize : normalSize
            )
            .shadow(color: port.dataType.color.opacity(isDragging ? 0.6 : 0.3), radius: isDragging ? 6 : 3)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .onHover { hovering in
                isHovered = hovering
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            registerCirclePosition(geometry.frame(in: .named(CanvasCoordinateSpace.name)))
                        }
                        .onChange(of: geometry.frame(in: .named(CanvasCoordinateSpace.name))) { _, frame in
                            registerCirclePosition(frame)
                        }
                }
            )
            .accessibilityLabel("\(port.dataType.displayName) \(isOutput ? "output" : "input") port")
            .accessibilityHint("Double tap to connect")
            .accessibilityAddTraits(.isButton)
    }

    private func registerCirclePosition(_ frame: CGRect) {
        guard let nodeId, let canvasState else { return }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        canvasState.registerPort(
            nodeId: nodeId,
            portId: port.id,
            isOutput: isOutput,
            dataType: port.dataType,
            position: center
        )
    }

    private var connectionDragGesture: some Gesture {
        DragGesture(coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onDragStart?(value.startLocation)
                }
                onDragUpdate?(value.location)
            }
            .onEnded { value in
                isDragging = false
                onDragEnd?(value.location)
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            PortView(
                port: PortDefinition(id: "string", label: "Text", dataType: .string),
                isOutput: false,
                nodeId: nil,
                canvasState: nil,
                onDragStart: nil,
                onDragUpdate: nil,
                onDragEnd: nil
            )

            PortView(
                port: PortDefinition(id: "image", label: "Image", dataType: .image),
                isOutput: true,
                nodeId: nil,
                canvasState: nil,
                onDragStart: nil,
                onDragUpdate: nil,
                onDragEnd: nil
            )

            PortView(
                port: PortDefinition(id: "audio", label: "Audio", dataType: .audio),
                isOutput: false,
                nodeId: nil,
                canvasState: nil,
                onDragStart: nil,
                onDragUpdate: nil,
                onDragEnd: nil
            )
        }
        .padding()
        .background(Color(white: 0.15, opacity: 0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
