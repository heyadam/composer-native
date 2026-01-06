//
//  PreviewSidebarHeader.swift
//  composer
//
//  Header for the preview sidebar with title and close button
//

import SwiftUI

/// Header view with title showing output count and close button
struct PreviewSidebarHeader: View {
    let outputCount: Int
    let onClose: () -> Void

    var body: some View {
        HStack {
            Label("Outputs", systemImage: "tray.full")
                .font(.headline)

            if outputCount > 0 {
                Text("(\(outputCount))")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Close", systemImage: "xmark.circle.fill") {
                onClose()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
