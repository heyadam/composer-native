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
    @State private var showSettings = false
    @State private var canvasViewModel: FlowCanvasViewModel?
    @State private var showDebugConsole = false

    // MARK: - View Body

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                sidebar
            } detail: {
                if let flow = selectedFlow {
                    FlowCanvasView(flow: flow) { viewModel in
                        canvasViewModel = viewModel
                    }
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

            // Debug Console
            if showDebugConsole, let flow = selectedFlow {
                DebugConsoleView(flow: flow)
            }
        }
        .onAppear {
            // Initialize debug logger
            DebugLogger.shared.logEvent("App launched")

            // Select first flow or create one if none exist
            if flows.isEmpty {
                createDefaultFlow()
            } else if selectedFlow == nil {
                selectedFlow = flows.first
            }
        }
        .onChange(of: selectedFlow) { _, newFlow in
            // Log flow state when selection changes
            if let flow = newFlow {
                DebugLogger.shared.logFlowState(flow)
            }
        }
        .onChange(of: selectedFlow?.nodes.count) { _, _ in
            // Log flow state when node count changes
            if let flow = selectedFlow {
                DebugLogger.shared.logFlowState(flow)
            }
        }
        .onChange(of: selectedFlow?.edges.count) { _, _ in
            // Log flow state when edge count changes
            if let flow = selectedFlow {
                DebugLogger.shared.logFlowState(flow)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
                .contextMenu {
                    Button(role: .destructive) {
                        deleteFlow(flow)
                    } label: {
                        Label("Delete", systemImage: "trash")
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
            // Run button
            Button {
                Task {
                    await canvasViewModel?.executeFlow()
                }
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(canvasViewModel?.isExecuting ?? false)

            Divider()

            Menu {
                Button {
                    addNode(.textInput, to: flow)
                } label: {
                    Label("Text Input", systemImage: NodeType.textInput.icon)
                }

                Button {
                    addNode(.textGeneration, to: flow)
                } label: {
                    Label("Text Generation", systemImage: NodeType.textGeneration.icon)
                }

                Button {
                    addNode(.imageGeneration, to: flow)
                } label: {
                    Label("Image Generation", systemImage: NodeType.imageGeneration.icon)
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

            Divider()

            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
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
            let flowId = flows[index].id
            let wasSelected = (selectedFlow?.id == flowId)

            modelContext.safeDelete(flowId: flowId)

            if wasSelected {
                selectedFlow = nil
            }
        }
    }

    private func deleteFlow(_ flow: Flow) {
        let flowId = flow.id

        // Smart selection: select adjacent flow before deleting
        if selectedFlow?.id == flowId {
            if let currentIndex = flows.firstIndex(where: { $0.id == flowId }) {
                if currentIndex > 0 {
                    selectedFlow = flows[currentIndex - 1]
                } else if flows.count > 1 {
                    selectedFlow = flows[1]
                } else {
                    selectedFlow = nil
                }
            }
        }

        modelContext.safeDelete(flowId: flowId)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flow.self, FlowNode.self, FlowEdge.self], inMemory: true)
}
