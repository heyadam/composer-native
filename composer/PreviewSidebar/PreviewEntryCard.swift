//
//  PreviewEntryCard.swift
//  composer
//
//  Individual card displaying output from a PreviewOutput node
//

import SwiftUI

/// Card displaying a single preview entry with status and typed content
struct PreviewEntryCard: View {
    let entry: PreviewEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status and node label
            HStack(spacing: 8) {
                StatusIndicator(status: entry.status)

                Text(entry.nodeLabel)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Content based on output type
            if let error = entry.error {
                ErrorOutputContent(error: error)
            } else if let text = entry.stringOutput {
                TextOutputContent(text: text)
                    .frame(maxHeight: 200)
            } else if let imageData = entry.imageOutput {
                ImageOutputContent(imageData: imageData)
            } else if let audioData = entry.audioOutput {
                AudioOutputContent(audioData: audioData)
            } else if entry.status == .running {
                runningPlaceholder
            } else if entry.status == .idle {
                idlePlaceholder
            }
        }
    }

    private var runningPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Processing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var idlePlaceholder: some View {
        Text("Awaiting execution")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
    }
}
