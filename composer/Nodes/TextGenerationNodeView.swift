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
            VStack(alignment: .leading, spacing: 10) {
                // Model info with enhanced styling
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(data.provider)/\(data.model)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }

                // Output preview or status message
                if data.executionStatus == .running {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    }
                } else if let error = data.executionError {
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.2))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                                }
                        }
                } else if !data.executionOutput.isEmpty {
                    ScrollView {
                        Text(data.executionOutput)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 90)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            }
                    }
                } else {
                    Text("Connect a prompt and run the flow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
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
