//
//  TextGenerationNode.swift
//  composer
//
//  Self-contained text generation (LLM) node definition
//

import SwiftUI

/// Data stored in TextGeneration nodes
struct TextGenerationNodeData: Codable {
    var provider: String = "openai"
    var model: String = "gpt-4o"
    var executionStatus: ExecutionStatus = .idle
    var executionOutput: String = ""
    var executionError: String?
}

/// Text generation node that calls LLM APIs
enum TextGenerationNode: NodeDefinition {
    static let nodeType: NodeType = .textGeneration

    // MARK: - Data

    typealias NodeData = TextGenerationNodeData

    static var defaultData: NodeData { NodeData() }

    // MARK: - Display

    static let displayName = "Text Generation"
    static let icon = "sparkles"
    static let category: NodeCategory = .llm

    // MARK: - Ports

    static let inputPorts: [PortDefinition] = [
        PortDefinition(id: PortID.textGenInputPrompt, label: "Prompt", dataType: .string, isRequired: true),
        PortDefinition(id: PortID.textGenInputSystem, label: "System", dataType: .string, isRequired: false)
    ]

    static let outputPorts: [PortDefinition] = [
        PortDefinition(id: PortID.textGenOutput, label: "Output", dataType: .string, isRequired: false)
    ]

    // MARK: - View

    @MainActor
    static func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> some View {
        TextGenerationNodeContent(
            node: node,
            viewModel: viewModel,
            state: state,
            connectionViewModel: connectionViewModel
        )
    }

    // MARK: - Execution

    static let isExecutable = true

    @MainActor
    static func execute(
        node: FlowNode,
        inputs: NodeInputs,
        context: ExecutionContext
    ) async throws -> NodeOutputs {
        var data = node.decodeData(NodeData.self) ?? defaultData

        // Set status to running
        data.executionStatus = .running
        data.executionOutput = ""
        data.executionError = nil
        node.encodeData(data)

        // Gather inputs
        let prompt = inputs.string(for: PortID.textGenInputPrompt) ?? ""
        let system = inputs.string(for: PortID.textGenInputSystem)

        var apiInputs: [String: String] = ["prompt": prompt]
        if let system {
            apiInputs["system"] = system
        }

        // Execute via API
        var output = ""

        do {
            let stream = await ExecutionService.shared.execute(
                nodeType: "text-generation",
                inputs: apiInputs,
                provider: data.provider,
                model: data.model
            )

            for try await event in stream {
                switch event {
                case .text(let text):
                    output += text
                    data.executionOutput = output
                    node.encodeData(data)

                case .error(let message):
                    data.executionStatus = .error
                    data.executionError = message
                    node.encodeData(data)
                    throw NodeExecutionError.apiError(message)

                case .done:
                    break

                default:
                    break
                }
            }

            // Success
            data.executionStatus = .success
            data.executionOutput = output
            node.encodeData(data)

            var outputs = NodeOutputs()
            outputs[PortID.textGenOutput] = .string(output)
            return outputs

        } catch let execError as NodeExecutionError {
            // Re-throw execution errors (already stored in node data)
            throw execError
        } catch {
            // Store error for UI display, then throw
            data.executionStatus = .error
            data.executionError = error.localizedDescription
            node.encodeData(data)
            throw NodeExecutionError.executionFailed(error.localizedDescription)
        }
    }

    // MARK: - Output Access

    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        guard portId == PortID.textGenOutput else { return nil }
        let data = node.decodeData(NodeData.self) ?? defaultData
        guard !data.executionOutput.isEmpty else { return nil }
        return .string(data.executionOutput)
    }

    // MARK: - Execution Status

    @MainActor
    static func getExecutionStatus(node: FlowNode) -> ExecutionStatus? {
        let data = node.decodeData(NodeData.self) ?? defaultData
        return data.executionStatus
    }
}

// MARK: - Content View

private struct TextGenerationNodeContent: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var data: TextGenerationNodeData = TextGenerationNode.defaultData
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
            if let storedData = node.decodeData(TextGenerationNodeData.self) {
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

        if let storedData = node.decodeData(TextGenerationNode.NodeData.self) {
            data = storedData
        }
        hasInitializedData = true
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TextGenerationNode.makeContentView(
            node: FlowNode(nodeType: .textGeneration, position: .zero, label: "GPT-4o"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
