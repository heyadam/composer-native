//
//  ExecutableNode.swift (Template)
//
//  Copy this template for nodes that perform async work:
//  - API calls
//  - AI/LLM inference
//  - File operations
//  - Any operation needing progress/error states
//
//  CUSTOMIZATION MARKERS:
//  - [NODE_NAME] → Your node name in PascalCase (e.g., "TextGeneration")
//  - [node_name] → Your node name in camelCase (e.g., "textGeneration")
//  - [node-name] → Your node name in kebab-case (e.g., "text-gen")
//  - [ICON] → SF Symbol name (e.g., "sparkles")
//  - [CATEGORY] → NodeCategory case (e.g., .llm, .integration)
//

import SwiftUI

// MARK: - Node Data

/// Data stored in [NODE_NAME] nodes
/// Executable nodes need: executionStatus, executionOutput, executionError
struct [NODE_NAME]NodeData: Codable {
    // CUSTOMIZE: Add configuration properties
    var config: String = "default"

    // Required for executable nodes
    var executionStatus: ExecutionStatus = .idle
    var executionOutput: String = ""
    var executionError: String?
}

// MARK: - Node Definition

/// [NODE_NAME] node - performs async operations
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

    // CUSTOMIZE: Define input ports
    static let inputPorts: [PortDefinition] = [
        PortDefinition(
            id: PortID.[node_name]Input,
            label: "Input",
            dataType: .string,
            isRequired: true
        )
    ]

    // CUSTOMIZE: Define output ports
    static let outputPorts: [PortDefinition] = [
        PortDefinition(
            id: PortID.[node_name]Output,
            label: "Output",
            dataType: .string,
            isRequired: false
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

        // Gather inputs from connected nodes
        let inputValue = inputs.string(for: PortID.[node_name]Input) ?? ""

        // CUSTOMIZE: Perform your async operation here
        var output = ""

        do {
            // Example: Call an API service
            // let stream = await SomeService.shared.execute(input: inputValue)
            //
            // for try await event in stream {
            //     switch event {
            //     case .text(let text):
            //         output += text
            //         data.executionOutput = output
            //         node.encodeData(data)
            //     case .error(let message):
            //         data.executionStatus = .error
            //         data.executionError = message
            //         node.encodeData(data)
            //         throw NodeExecutionError.apiError(message)
            //     case .done:
            //         break
            //     }
            // }

            // Placeholder: Echo input for template
            output = "Processed: \(inputValue)"

            // Success
            data.executionStatus = .success
            data.executionOutput = output
            node.encodeData(data)

            var outputs = NodeOutputs()
            outputs[PortID.[node_name]Output] = .string(output)
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
        guard portId == PortID.[node_name]Output else { return nil }
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

private struct [NODE_NAME]NodeContent: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var data: [NODE_NAME]NodeData = [NODE_NAME]Node.defaultData
    @State private var hasInitializedData = false

    var body: some View {
        NodeFrame(
            icon: node.nodeType.icon,
            title: node.label,
            status: nodeStatus,  // Shows execution state
            inputPorts: node.inputPorts,
            outputPorts: node.outputPorts,
            nodeId: node.id,
            canvasState: state,
            connectionViewModel: connectionViewModel
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // CUSTOMIZE: Add configuration UI
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(data.config)
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

                // Execution state display
                if data.executionStatus == .running {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
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
                    Text("Connect inputs and run the flow")
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
            // Re-decode data when node's underlying data changes (during execution)
            if let storedData = node.decodeData([NODE_NAME]NodeData.self) {
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

        if let storedData = node.decodeData([NODE_NAME]Node.NodeData.self) {
            data = storedData
        }
        hasInitializedData = true
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
