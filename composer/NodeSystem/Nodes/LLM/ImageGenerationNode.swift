//
//  ImageGenerationNode.swift
//  composer
//
//  Self-contained image generation node definition
//

import SwiftUI

/// Data stored in ImageGeneration nodes
struct ImageGenerationNodeData: Codable {
    // Hardcoded defaults (no config UI)
    var executionStatus: ExecutionStatus = .idle
    var executionOutput: Data?
    var executionMimeType: String?
    var partialImageData: Data?
    var partialImageIndex: Int?
    var executionError: String?
}

/// Image generation node that calls image generation APIs
enum ImageGenerationNode: NodeDefinition {
    static let nodeType: NodeType = .imageGeneration

    // MARK: - Data

    typealias NodeData = ImageGenerationNodeData

    static var defaultData: NodeData { NodeData() }

    // MARK: - Display

    static let displayName = "Image Generation"
    static let icon = "photo.badge.plus"
    static let category: NodeCategory = .llm

    // MARK: - Ports

    static let inputPorts: [PortDefinition] = [
        PortDefinition(id: PortID.imageGenInputPrompt, label: "Prompt", dataType: .string, isRequired: true)
    ]

    static let outputPorts: [PortDefinition] = [
        PortDefinition(id: PortID.imageGenOutput, label: "Image", dataType: .image, isRequired: false)
    ]

    // MARK: - View

    @MainActor
    static func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> some View {
        ImageGenerationNodeContent(
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
        data.executionOutput = nil
        data.executionMimeType = nil
        data.partialImageData = nil
        data.partialImageIndex = nil
        data.executionError = nil
        node.encodeData(data)

        // Gather inputs - require non-empty prompt
        let prompt = inputs.string(for: PortID.imageGenInputPrompt) ?? ""
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            data.executionStatus = .error
            data.executionError = "Prompt is required for image generation"
            node.encodeData(data)
            throw NodeExecutionError.executionFailed("Prompt is required for image generation")
        }

        // Hardcoded image generation parameters
        let apiInputs: [String: Any] = [
            "prompt": prompt,
            "size": "1024x1024",
            "quality": "low",
            "outputFormat": "webp",
            "partialImages": 3  // Must be Int, not String, for OpenAI API
        ]

        // Execute via API
        do {
            let stream = await ExecutionService.shared.execute(
                nodeType: "image-generation",
                inputs: apiInputs,
                provider: "openai",
                model: "gpt-5.2"
            )

            for try await event in stream {
                switch event {
                case .partialImage(let imageData, let index, _):
                    data.partialImageData = imageData
                    data.partialImageIndex = index
                    node.encodeData(data)

                case .image(let imageData, let mimeType):
                    data.executionOutput = imageData
                    data.executionMimeType = mimeType
                    data.partialImageData = nil
                    data.partialImageIndex = nil
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

            // Verify we received image data
            guard let imageData = data.executionOutput else {
                data.executionStatus = .error
                data.executionError = "No image received from API"
                node.encodeData(data)
                throw NodeExecutionError.executionFailed("No image received from API")
            }

            // Success
            data.executionStatus = .success
            node.encodeData(data)

            var outputs = NodeOutputs()
            outputs[PortID.imageGenOutput] = .image(imageData)
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
        guard portId == PortID.imageGenOutput else { return nil }
        let data = node.decodeData(NodeData.self) ?? defaultData
        guard let imageData = data.executionOutput else { return nil }
        return .image(imageData)
    }

    // MARK: - Execution Status

    @MainActor
    static func getExecutionStatus(node: FlowNode) -> ExecutionStatus? {
        let data = node.decodeData(NodeData.self) ?? defaultData
        return data.executionStatus
    }
}

// MARK: - Content View

private struct ImageGenerationNodeContent: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    @State private var data: ImageGenerationNodeData = ImageGenerationNode.defaultData
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
                // Model info with enhanced styling (hardcoded)
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("openai/gpt-5.2")
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

                // Image output or status
                if data.executionStatus == .running {
                    runningView
                } else if let error = data.executionError {
                    errorView(error)
                } else if let imageData = data.executionOutput {
                    successView(imageData)
                } else {
                    placeholderView
                }
            }
        }
        .onAppear {
            initializeDataIfNeeded()
        }
        .onChange(of: node.dataJSON) { _, _ in
            // Re-decode data when node's underlying data changes (e.g., during execution)
            if let storedData = node.decodeData(ImageGenerationNodeData.self) {
                data = storedData
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var runningView: some View {
        if let partialData = data.partialImageData {
            // Show partial image with progress overlay
            ZStack {
                imageView(from: partialData)
                    .opacity(0.7)

                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.9)
                    if let index = data.partialImageIndex {
                        Text("Refining... (step \(index))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .padding(8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
        } else {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Generating image...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 100)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private func successView(_ imageData: Data) -> some View {
        imageView(from: imageData)
    }

    @ViewBuilder
    private func imageView(from imageData: Data) -> some View {
        #if os(macOS)
        if let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            imagePlaceholder
        }
        #else
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            imagePlaceholder
        }
        #endif
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 100)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.5))
            }
    }

    @ViewBuilder
    private func errorView(_ error: String) -> some View {
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
    }

    private var placeholderView: some View {
        Text("Connect a prompt and run the flow")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    // MARK: - Helpers

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

        if let storedData = node.decodeData(ImageGenerationNode.NodeData.self) {
            data = storedData
        }
        hasInitializedData = true
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ImageGenerationNode.makeContentView(
            node: FlowNode(nodeType: .imageGeneration, position: .zero, label: "Image Gen"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
