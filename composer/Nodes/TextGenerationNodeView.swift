//
//  TextGenerationNodeView.swift
//  composer
//
//  Text generation node with execution status and streaming output
//

import SwiftUI

struct TextGenerationNodeView: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var data: TextGenerationData = TextGenerationData()
    @State private var hasInitializedData = false

    var body: some View {
        NodeFrame(
            icon: node.nodeType.icon,
            title: node.label,
            status: nodeStatus,
            inputPorts: node.inputPorts,
            outputPorts: node.outputPorts,
            nodeId: node.id,
            canvasState: state,
            connectionViewModel: connectionViewModel
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // Model info
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(data.provider)/\(data.model)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Output preview or status message
                if data.executionStatus == .running {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Generating...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } else if let error = data.executionError {
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if !data.executionOutput.isEmpty {
                    ScrollView {
                        Text(data.executionOutput)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 80)
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("Connect a prompt and run the flow")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            initializeDataIfNeeded()
        }
        .onChange(of: node.dataJSON) { _, _ in
            // Re-decode data when node's underlying data changes (e.g., during execution)
            if let storedData = node.decodeData(TextGenerationData.self) {
                data = storedData
            }
        }
    }

    private var nodeStatus: NodeStatus {
        switch data.executionStatus {
        case .idle: return .idle
        case .running: return .running
        case .success: return .success
        case .error: return .error
        }
    }

    private func initializeDataIfNeeded() {
        guard !hasInitializedData else { return }

        if let storedData = node.decodeData(TextGenerationData.self) {
            data = storedData
        }
        hasInitializedData = true
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TextGenerationNodeView(
            node: FlowNode(nodeType: .textGeneration, position: .zero, label: "GPT-4o"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
