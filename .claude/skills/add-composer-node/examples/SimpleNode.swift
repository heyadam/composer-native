//
//  SimpleNode.swift (Template)
//
//  Copy this template for pass-through nodes that:
//  - Store user input
//  - Transform data synchronously
//  - Display connected values
//
//  CUSTOMIZATION MARKERS:
//  - [NODE_NAME] → Your node name in PascalCase (e.g., "TextInput")
//  - [node_name] → Your node name in camelCase (e.g., "textInput")
//  - [node-name] → Your node name in kebab-case (e.g., "text-input")
//  - [ICON] → SF Symbol name (e.g., "text.alignleft")
//  - [CATEGORY] → NodeCategory case (e.g., .input, .transform, .output)
//

import SwiftUI
import SwiftData

// MARK: - Node Data

/// Data stored in [NODE_NAME] nodes
/// Add properties for any state the node needs to persist
struct [NODE_NAME]NodeData: Codable {
    // CUSTOMIZE: Add your node's properties
    var text: String = ""
}

// MARK: - Node Definition

/// [NODE_NAME] node description
/// CUSTOMIZE: Update this doc comment
enum [NODE_NAME]Node: NodeDefinition {
    static let nodeType: NodeType = .[node_name]

    // MARK: - Data

    typealias NodeData = [NODE_NAME]NodeData

    static var defaultData: NodeData { NodeData() }

    // MARK: - Display

    // CUSTOMIZE: Update display properties
    static let displayName = "[NODE_NAME]"
    static let icon = "[ICON]"
    static let category: NodeCategory = [CATEGORY]

    // MARK: - Ports

    // CUSTOMIZE: Define input ports (empty array if none)
    static let inputPorts: [PortDefinition] = []

    // CUSTOMIZE: Define output ports
    static let outputPorts: [PortDefinition] = [
        PortDefinition(
            id: PortID.[node_name]Output,
            label: "Output",
            dataType: .string,
            isRequired: true
        )
    ]

    // MARK: - View

    @MainActor
    static func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> some View {
        [NODE_NAME]NodeContent(
            node: node,
            viewModel: viewModel,
            state: state,
            connectionViewModel: connectionViewModel
        )
    }

    // MARK: - Execution

    static let isExecutable = false

    @MainActor
    static func execute(
        node: FlowNode,
        inputs: NodeInputs,
        context: ExecutionContext
    ) async throws -> NodeOutputs {
        // Fetch fresh node from ModelContext (iOS SwiftData pattern)
        let nodeId = node.id
        let predicate = #Predicate<FlowNode> { $0.id == nodeId }

        var outputValue = ""

        if let freshNodes = try? context.modelContext.fetch(
            FetchDescriptor(predicate: predicate)
        ), let freshNode = freshNodes.first {
            let data = freshNode.decodeData(NodeData.self) ?? defaultData
            outputValue = data.text
        } else {
            // Fallback to passed node if fetch fails
            let data = node.decodeData(NodeData.self) ?? defaultData
            outputValue = data.text
        }

        var outputs = NodeOutputs()
        outputs[PortID.[node_name]Output] = .string(outputValue)
        return outputs
    }

    // MARK: - Output Access

    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        guard portId == PortID.[node_name]Output else { return nil }
        let data = node.decodeData(NodeData.self) ?? defaultData
        return .string(data.text)
    }
}

// MARK: - Content View

private struct [NODE_NAME]NodeContent: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    // CUSTOMIZE: Add @State properties for local UI state
    @State private var text: String = ""
    @State private var hasInitializedText = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NodeFrame(
            icon: node.nodeType.icon,
            title: node.label,
            status: nil,  // nil for non-executable nodes
            inputPorts: node.inputPorts,
            outputPorts: node.outputPorts,
            nodeId: node.id,
            canvasState: state,
            connectionViewModel: connectionViewModel
        ) {
            // CUSTOMIZE: Replace with your node's content
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
                .frame(minHeight: 70, maxHeight: 140)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    // Save on every change (user may run flow without unfocusing)
                    guard hasInitializedText else { return }
                    node.encodeData([NODE_NAME]NodeData(text: newValue))
                    node.flow?.touch()
                }
                .onChange(of: isFocused) { _, newValue in
                    state.isEditingNode = newValue
                    if newValue {
                        viewModel?.beginEditing()
                    } else {
                        viewModel?.endEditing()
                    }
                }
        }
        .onAppear {
            initializeTextIfNeeded()
        }
        .onChange(of: viewModel?.textContent) { _, newValue in
            if !hasInitializedText {
                text = newValue ?? ""
                hasInitializedText = true
            }
        }
    }

    private func initializeTextIfNeeded() {
        guard !hasInitializedText else { return }

        // Try viewModel first, fall back to node's stored data
        if let content = viewModel?.textContent {
            text = content
        } else if let storedData = node.decodeData([NODE_NAME]NodeData.self) {
            text = storedData.text
        }
        // CRITICAL: Always mark as initialized, even for empty nodes
        hasInitializedText = true
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        [NODE_NAME]Node.makeContentView(
            node: FlowNode(
                nodeType: .[node_name],
                position: .zero,
                label: "[NODE_NAME]"
            ),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
