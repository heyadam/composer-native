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
                    node.encodeData(TextInputData(text: newValue))
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
        } else if let storedData = node.decodeData(TextInputData.self) {
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

        TextInputNodeView(
            node: FlowNode(nodeType: .textInput, position: .zero, label: "User Prompt"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
