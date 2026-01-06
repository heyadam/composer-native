//
//  TextInputNode.swift
//  composer
//
//  Self-contained text input node definition
//

import SwiftUI
import SwiftData

/// Data stored in TextInput nodes
struct TextInputNodeData: Codable {
    var text: String = ""
}

/// Text input node for entering text that flows to downstream nodes
enum TextInputNode: NodeDefinition {
    static let nodeType: NodeType = .textInput

    // MARK: - Data

    typealias NodeData = TextInputNodeData

    static var defaultData: NodeData { NodeData() }

    // MARK: - Display

    static let displayName = "Text Input"
    static let icon = "text.alignleft"
    static let category: NodeCategory = .input

    // MARK: - Ports

    static let inputPorts: [PortDefinition] = []

    static let outputPorts: [PortDefinition] = [
        PortDefinition(id: PortID.textInputOutput, label: "Output", dataType: .string, isRequired: true)
    ]

    // MARK: - View

    @MainActor
    static func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> some View {
        TextInputNodeContent(
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

        var textValue = ""

        if let freshNodes = try? context.modelContext.fetch(FetchDescriptor(predicate: predicate)),
           let freshNode = freshNodes.first {
            let data = freshNode.decodeData(NodeData.self) ?? defaultData
            textValue = data.text
        } else {
            // Fallback to passed node if fetch fails
            let data = node.decodeData(NodeData.self) ?? defaultData
            textValue = data.text
        }

        var outputs = NodeOutputs()
        outputs[PortID.textInputOutput] = .string(textValue)
        return outputs
    }

    // MARK: - Output Access

    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        guard portId == PortID.textInputOutput else { return nil }
        let data = node.decodeData(NodeData.self) ?? defaultData
        return .string(data.text)
    }
}

// MARK: - Content View

private struct TextInputNodeContent: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var text: String = ""
    @State private var hasInitializedText = false
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
            connectionViewModel: connectionViewModel
        ) {
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
                    // Save on EVERY change, not just unfocus
                    // Critical: User may click Play without unfocusing the text editor
                    guard hasInitializedText else { return }
                    node.encodeData(TextInputNodeData(text: newValue))
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
            // Sync when viewModel becomes available or content changes externally
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
        } else if let storedData = node.decodeData(TextInputNodeData.self) {
            text = storedData.text
        }
        // Always mark as initialized - even for empty nodes
        // This is critical: without this, onChange(of: text) returns early
        // and user input is never saved
        hasInitializedText = true
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TextInputNode.makeContentView(
            node: FlowNode(nodeType: .textInput, position: .zero, label: "User Prompt"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
