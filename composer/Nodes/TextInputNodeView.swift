//
//  TextInputNodeView.swift
//  composer
//
//  Text input node with editable text field
//

import SwiftUI

struct TextInputNodeView: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

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
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(minHeight: 60, maxHeight: 120)
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    state.isEditingNode = newValue
                    if newValue {
                        viewModel?.beginEditing()
                    } else {
                        viewModel?.endEditing()
                        // Save text to node
                        viewModel?.textContent = text
                    }
                }
        }
        .onAppear {
            text = viewModel?.textContent ?? ""
        }
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TextInputNodeView(
            node: FlowNode(nodeType: .textInput, position: .zero, label: "User Prompt"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
