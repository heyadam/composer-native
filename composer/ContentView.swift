//
//  ContentView.swift
//  composer
//
//  Created by Adam Presson on 1/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flows: [Flow]

    @State private var selectedFlow: Flow?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let flow = selectedFlow {
                FlowCanvasView(flow: flow)
                    .toolbar {
                        canvasToolbar(for: flow)
                    }
            } else {
                ContentUnavailableView(
                    "No Flow Selected",
                    systemImage: "square.grid.2x2",
                    description: Text("Select a flow from the sidebar or create a new one")
                )
            }
        }
        .onAppear {
            // Select first flow or create one if none exist
            if flows.isEmpty {
                createDefaultFlow()
            } else if selectedFlow == nil {
                selectedFlow = flows.first
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedFlow) {
            ForEach(flows) { flow in
                NavigationLink(value: flow) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(flow.name)
                            .font(.headline)
                        Text("\(flow.nodes.count) nodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteFlows)
        }
        .navigationTitle("Flows")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Button(action: createFlow) {
                    Label("New Flow", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Canvas Toolbar

    @ToolbarContentBuilder
    private func canvasToolbar(for flow: Flow) -> some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Button {
                    addNode(.textInput, to: flow)
                } label: {
                    Label("Text Input", systemImage: NodeType.textInput.icon)
                }

                Button {
                    addNode(.previewOutput, to: flow)
                } label: {
                    Label("Preview Output", systemImage: NodeType.previewOutput.icon)
                }
            } label: {
                Label("Add Node", systemImage: "plus.rectangle")
            }

            Divider()

            Button {
                modelContext.undoManager?.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!(modelContext.undoManager?.canUndo ?? false))

            Button {
                modelContext.undoManager?.redo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!(modelContext.undoManager?.canRedo ?? false))
        }
    }

    // MARK: - Actions

    private func createFlow() {
        let flow = Flow(name: "New Flow")
        modelContext.insert(flow)
        selectedFlow = flow
    }

    private func createDefaultFlow() {
        let flow = Flow(name: "My First Flow")

        // Add sample nodes
        let textInput = FlowNode(
            nodeType: .textInput,
            position: CGPoint(x: 100, y: 200),
            label: "User Prompt"
        )
        textInput.flow = flow

        let preview = FlowNode(
            nodeType: .previewOutput,
            position: CGPoint(x: 400, y: 200),
            label: "Output"
        )
        preview.flow = flow

        flow.nodes = [textInput, preview]

        modelContext.insert(flow)
        selectedFlow = flow
    }

    private func addNode(_ type: NodeType, to flow: Flow) {
        // Add node at center of canvas (approximate)
        let node = FlowNode(
            nodeType: type,
            position: CGPoint(x: 250, y: 250)
        )
        node.flow = flow
        flow.nodes.append(node)
        flow.touch()
    }

    private func deleteFlows(offsets: IndexSet) {
        for index in offsets {
            let flow = flows[index]
            if selectedFlow == flow {
                selectedFlow = nil
            }
            modelContext.delete(flow)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flow.self, FlowNode.self, FlowEdge.self], inMemory: true)
}
