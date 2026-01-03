//
//  PreviewOutputNodeView.swift
//  composer
//
//  Preview output node for displaying connected data
//

import SwiftUI

struct PreviewOutputNodeView: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    var body: some View {
        NodeFrame(
            icon: node.nodeType.icon,
            title: node.label,
            status: nil,
            inputPorts: node.inputPorts,
            outputPorts: node.outputPorts,
            nodeId: node.id,
            canvasState: state,
            onPortDragStart: handlePortDragStart,
            onPortDragUpdate: handlePortDragUpdate,
            onPortDragEnd: handlePortDragEnd
        ) {
            previewContent
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview area
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.2))
                .frame(minHeight: 80, maxHeight: 160)
                .overlay {
                    // Show preview based on connected inputs
                    if let connectedData = getConnectedData() {
                        connectedDataView(connectedData)
                    } else {
                        Text("No input connected")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
        }
    }

    @ViewBuilder
    private func connectedDataView(_ data: PreviewData) -> some View {
        switch data {
        case .text(let string):
            ScrollView {
                Text(string)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }

        case .image(let image):
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(4)
            #else
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(4)
            #endif

        case .audio:
            VStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Audio")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Get connected data from incoming edges
    private func getConnectedData() -> PreviewData? {
        // Check incoming edges for connected data
        guard let incomingEdge = node.incomingEdges.first,
              let sourceNode = incomingEdge.sourceNode else {
            return nil
        }

        // For now, just return sample text if connected to text input
        if sourceNode.nodeType == .textInput {
            let textData = sourceNode.decodeData(TextInputData.self)
            if let text = textData?.text, !text.isEmpty {
                return .text(text)
            }
        }

        return nil
    }

    // MARK: - Port Drag Handling

    private func handlePortDragStart(_ port: PortDefinition, _ isOutput: Bool, _ position: CGPoint) {
        guard let connectionViewModel else { return }

        // Use registered port position (center of circle) instead of touch location
        let portKey = "\(node.id):\(port.id)"
        let portScreenPosition = state.portPositions[portKey] ?? position

        let connectionPoint = ConnectionPoint(
            nodeId: node.id,
            portId: port.id,
            portType: port.dataType,
            isOutput: isOutput,
            position: state.canvasToWorld(portScreenPosition)
        )

        connectionViewModel.beginConnection(from: connectionPoint)
        state.activeConnection = connectionPoint
    }

    private func handlePortDragUpdate(_ port: PortDefinition, _ isOutput: Bool, _ position: CGPoint) {
        state.connectionEndPosition = position
        connectionViewModel?.updateConnection(to: position)
    }

    private func handlePortDragEnd(_ port: PortDefinition, _ isOutput: Bool, _ position: CGPoint) {
        defer {
            state.activeConnection = nil
            state.connectionEndPosition = nil
        }

        // Check if we dropped over a compatible port
        if let hitPort = state.findPort(near: position, excludingNode: node.id) {
            // Found a port - try to complete the connection
            let targetPoint = ConnectionPoint(
                nodeId: hitPort.nodeId,
                portId: hitPort.portId,
                portType: findPortType(nodeId: hitPort.nodeId, portId: hitPort.portId) ?? .string,
                isOutput: !isOutput  // Target should be opposite direction
            )

            if connectionViewModel?.canConnect(to: targetPoint) == true {
                try? connectionViewModel?.completeConnection(to: targetPoint)
                return
            }
        }

        // No valid port found, cancel the connection
        connectionViewModel?.cancelConnection()
    }

    private func findPortType(nodeId: UUID, portId: String) -> PortDataType? {
        // Search through all nodes to find the port type
        guard let flow = node.flow else { return nil }
        for flowNode in flow.nodes {
            if flowNode.id == nodeId {
                for inputPort in flowNode.inputPorts {
                    if inputPort.id == portId { return inputPort.dataType }
                }
                for outputPort in flowNode.outputPorts {
                    if outputPort.id == portId { return outputPort.dataType }
                }
            }
        }
        return nil
    }
}

// MARK: - Preview Data Type

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

enum PreviewData {
    case text(String)
    case image(PlatformImage)
    case audio
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PreviewOutputNodeView(
            node: FlowNode(nodeType: .previewOutput, position: .zero, label: "Output"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
