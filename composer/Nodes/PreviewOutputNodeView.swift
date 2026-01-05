//
//  PreviewOutputNodeView.swift
//  composer
//
//  Preview output node for displaying connected data
//

import SwiftUI

struct PreviewOutputNodeView: View {
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

    /// Get connected data from all incoming edges
    private func getConnectedData() -> [PreviewData]? {
        var results: [PreviewData] = []

        // Check all incoming edges for connected data
        for edge in node.incomingEdges {
            guard let sourceNode = edge.sourceNode else { continue }

            switch edge.dataType {
            case .string:
                switch sourceNode.nodeType {
                case .textInput:
                    let textData = sourceNode.decodeData(TextInputData.self)
                    if let text = textData?.text, !text.isEmpty {
                        results.append(.text(text))
                    }
                case .textGeneration:
                    let genData = sourceNode.decodeData(TextGenerationData.self)
                    if let output = genData?.executionOutput, !output.isEmpty {
                        results.append(.text(output))
                    }
                default:
                    break
                }

            case .image:
                // Placeholder for image data
                break

            case .audio:
                // Placeholder for audio data
                results.append(.audio)

            case .pulse:
                // Pulse is a trigger signal, no preview content
                break
            }
        }

        return results.isEmpty ? nil : results
    }
}

// MARK: - Preview Data Type

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

enum PreviewData {
    case text(String)
    case image(PlatformImage)
    case audio
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PreviewOutputNodeView(
            node: FlowNode(nodeType: .previewOutput, position: .zero, label: "Output"),
            viewModel: nil,
            state: CanvasState(),
            connectionViewModel: nil
        )
    }
}
