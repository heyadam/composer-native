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
            initializeTextIfNeeded()
        }
        .onChange(of: viewModel?.textContent) { _, newValue in
            // Sync when viewModel becomes available or content changes externally
            if !hasInitializedText, let content = newValue {
                text = content
                hasInitializedText = true
            }
        }
    }

    private func initializeTextIfNeeded() {
        guard !hasInitializedText else { return }

        // Try viewModel first, fall back to node's stored data
        if let content = viewModel?.textContent {
            text = content
            hasInitializedText = true
        } else if let storedData = node.decodeData(TextInputData.self) {
            text = storedData.text
            hasInitializedText = true
        }
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
