//
//  OutputRenderers.swift
//  composer
//
//  Reusable content renderers for preview sidebar outputs
//

import SwiftUI

// MARK: - Status Indicator

/// Visual indicator for execution status
struct StatusIndicator: View {
    let status: ExecutionStatus

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .font(.system(size: 12, weight: .semibold))
    }

    private var iconName: String {
        switch status {
        case .idle:
            return "circle"
        case .running:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .idle:
            return .secondary
        case .running:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Text Output Content

/// Scrollable monospace text output
struct TextOutputContent: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(10)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Image Output Content

/// Platform-specific image output renderer
struct ImageOutputContent: View {
    let imageData: Data

    var body: some View {
        #if os(macOS)
        if let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            invalidImagePlaceholder
        }
        #else
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            invalidImagePlaceholder
        }
        #endif
    }

    private var invalidImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.fill.tertiary)
            .frame(height: 100)
            .overlay {
                Label("Invalid Image", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Audio Output Content

/// Basic audio output placeholder with play button
struct AudioOutputContent: View {
    let audioData: Data
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)

            // Waveform placeholder
            waveformPlaceholder
        }
        .padding(12)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var waveformPlaceholder: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.tint.opacity(0.6))
                    .frame(width: 3, height: CGFloat.random(in: 8...24))
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Error Content

/// Error message display
struct ErrorOutputContent: View {
    let error: String

    var body: some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
