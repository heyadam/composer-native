//
//  composerApp.swift
//  composer
//
//  Created by Adam Presson on 1/3/26.
//

import SwiftUI
import SwiftData

@main
struct composerApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Flow.self,
            FlowNode.self,
            FlowEdge.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)

            // Enable undo support
            container.mainContext.undoManager = UndoManager()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
