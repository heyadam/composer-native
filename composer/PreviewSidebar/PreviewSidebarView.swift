//
//  PreviewSidebarView.swift
//  composer
//
//  Main container for the preview sidebar
//

import SwiftUI

/// Preview sidebar showing outputs from PreviewOutput nodes
///
/// Uses iOS 26 Liquid Glass for the navigation layer appearance.
struct PreviewSidebarView: View {
    @Bindable var state: PreviewSidebarState
    @AppStorage("previewSidebarWidth") private var storedWidth: Double = 340

    var body: some View {
        VStack(spacing: 0) {
            PreviewSidebarHeader(
                outputCount: state.previewEntries.count,
                onClose: { state.isVisible = false }
            )

            Divider()

            PreviewOutputsContent(entries: state.previewEntries)
        }
        .frame(width: state.width)
        .glassEffect(in: .rect)
        .overlay(alignment: .leading) {
            ResizeHandle(width: $state.width)
        }
        .onAppear {
            state.width = storedWidth
        }
        .onChange(of: state.width) { _, newValue in
            storedWidth = newValue
        }
    }
}
