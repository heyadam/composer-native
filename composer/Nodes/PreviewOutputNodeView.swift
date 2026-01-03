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
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview area
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.2))
                .frame(minHeight: 80, maxHeight: 160)
                .overlay {
                    // Show preview based on connected inputs
                    if let previewData = getConnectedData() {
                        connectedDataView(previewData)
                    } else {
                        Text("No input connected")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
        }
    }

    @ViewBuilder
    private func connectedDataView(_ data: [PreviewData]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    previewItemView(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }

    @ViewBuilder
    private func previewItemView(_ data: PreviewData) -> some View {
        switch data {
        case .text(let string):
            Text(string)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .image(let image):
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            #else
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            #endif

        case .audio:
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text("Audio")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
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
                if sourceNode.nodeType == .textInput {
                    let textData = sourceNode.decodeData(TextInputData.self)
                    if let text = textData?.text, !text.isEmpty {
                        results.append(.text(text))
                    }
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
