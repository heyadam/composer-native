//
//  PreviewOutputsContent.swift
//  composer
//
//  Scrollable list of preview output entries
//

import SwiftUI

/// Content view displaying all preview entries using standard List
struct PreviewOutputsContent: View {
    let entries: [PreviewEntry]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label("No Outputs", systemImage: "tray")
            } description: {
                Text("Run a flow with Preview Output nodes to see results here")
            }
        } else {
            List(entries) { entry in
                PreviewEntryCard(entry: entry)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
}
