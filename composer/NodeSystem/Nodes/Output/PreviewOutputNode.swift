//
//  PreviewOutputNode.swift
//  composer
//
//  Self-contained preview output node definition
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// Data stored in PreviewOutput nodes (empty - displays connected inputs)
struct PreviewOutputNodeData: Codable {}

/// Preview output node for displaying connected data
enum PreviewOutputNode: NodeDefinition {
    static let nodeType: NodeType = .previewOutput

    // MARK: - Data

    typealias NodeData = PreviewOutputNodeData

    static var defaultData: NodeData { NodeData() }

    // MARK: - Display

    static let displayName = "Preview Output"
    static let icon = "eye"
    static let category: NodeCategory = .output

    // MARK: - Ports

    static let inputPorts: [PortDefinition] = [
        PortDefinition(id: PortID.previewInputString, label: "Text", dataType: .string, isRequired: false),
        PortDefinition(id: PortID.previewInputImage, label: "Image", dataType: .image, isRequired: false),
        PortDefinition(id: PortID.previewInputAudio, label: "Audio", dataType: .audio, isRequired: false)
    ]

    static let outputPorts: [PortDefinition] = []

    // MARK: - View

    @MainActor
    static func makeContentView(
        node: FlowNode,
        viewModel: NodeViewModel?,
        state: CanvasState,
        connectionViewModel: ConnectionViewModel?
    ) -> some View {
        PreviewOutputNodeContent(
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
        // Preview nodes don't produce outputs, they just display inputs
        NodeOutputs()
    }

    // MARK: - Output Access

    @MainActor
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue? {
        // Preview nodes have no outputs
        nil
    }
}

// MARK: - Preview Data Type

enum PreviewData {
    case text(String)
    case image(PlatformImage)
    case audio
}

// MARK: - Content View

private struct PreviewOutputNodeContent: View {
    let node: FlowNode
    let viewModel: NodeViewModel?
    let state: CanvasState
    let connectionViewModel: ConnectionViewModel?

    /// Trigger re-render when source nodes' data changes
    @State private var refreshTrigger = false

    /// Get all source node data hashes to detect changes
    private var sourceDataHash: Int {
        var hasher = Hasher()
        for edge in node.incomingEdges {
            if let sourceNode = edge.sourceNode {
                hasher.combine(sourceNode.dataJSON)
            }
        }
        return hasher.finalize()
    }

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
            previewContent
                .id(refreshTrigger) // Force refresh when trigger changes
        }
        .onChange(of: sourceDataHash) { _, _ in
            // Toggle to force view refresh when source data changes
            refreshTrigger.toggle()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview area with enhanced styling
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .frame(minHeight: 90, maxHeight: 180)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
                .overlay {
                    // Show preview based on connected inputs
                    if let previewData = getConnectedData() {
                        connectedDataView(previewData)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("No input connected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func connectedDataView(_ data: [PreviewData]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    previewItemView(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
    }

    @ViewBuilder
    private func previewItemView(_ data: PreviewData) -> some View {
        switch data {
        case .text(let string):
            Text(string)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                }

        case .image(let image):
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #else
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            #endif

        case .audio:
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Audio")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    /// Get connected data from all incoming edges using NodeRegistry.getOutputValue
    ///
    /// This is the key improvement: we use the registry to get output values
    /// instead of switching on node types directly.
    private func getConnectedData() -> [PreviewData]? {
        var results: [PreviewData] = []

        // Check all incoming edges for connected data
        for edge in node.incomingEdges {
            guard let sourceNode = edge.sourceNode else { continue }

            // Use NodeRegistry to get output value - no switch statement needed!
            if let value = NodeRegistry.getOutputValue(node: sourceNode, portId: edge.sourceHandle) {
                switch value {
                case .string(let text) where !text.isEmpty:
                    results.append(.text(text))

                case .image(let data):
                    #if os(macOS)
                    if let image = NSImage(data: data) {
                        results.append(.image(image))
                    }
                    #else
                    if let image = UIImage(data: data) {
                        results.append(.image(image))
                    }
                    #endif

                case .audio:
                    results.append(.audio)

                case .pulse:
                    // Pulse is a trigger signal, no preview content
                    break

                default:
                    break
                }
            }
        }

        return results.isEmpty ? nil : results
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PreviewOutputNode.makeContentView(
            node: FlowNode(nodeType: .previewOutput, position: .zero, label: "Output"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
