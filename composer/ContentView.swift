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

// MARK: - Debug Console

struct DebugConsoleView: View {
    let flow: Flow
    @State private var isExpanded = true
    @State private var copied = false

    private var debugText: String {
        var lines: [String] = []
        lines.append("=== DEBUG CONSOLE ===")
        lines.append("Flow: \(flow.name)")
        lines.append("Edges: \(flow.edges.count), Nodes: \(flow.nodes.count)")
        lines.append("")
        lines.append("EDGES:")
        if flow.edges.isEmpty {
            lines.append("  (no edges)")
        } else {
            for edge in flow.edges {
                let sourceInfo = edge.sourceNode.map { "\($0.label) [\($0.nodeType.rawValue)]" } ?? "nil"
                let targetInfo = edge.targetNode.map { "\($0.label) [\($0.nodeType.rawValue)]" } ?? "nil"
                lines.append("  Edge: \(edge.sourceHandle) → \(edge.targetHandle) (\(edge.dataType.rawValue))")
                lines.append("    sourceNode: \(sourceInfo)")
                lines.append("    targetNode: \(targetInfo)")
            }
        }
        lines.append("")
        lines.append("NODES:")
        for node in flow.nodes {
            lines.append("  \(node.label) [\(node.nodeType.rawValue)]")
            lines.append("    incomingEdges: \(node.incomingEdges.count), outgoingEdges: \(node.outgoingEdges.count)")
            if node.nodeType == .previewOutput {
                lines.append("    edge.dataType check:")
                for edge in node.incomingEdges {
                    lines.append("      edge dataType: \(edge.dataType.rawValue)")
                    if let src = edge.sourceNode {
                        lines.append("      sourceNode: \(src.label) [\(src.nodeType.rawValue)]")
                        if src.nodeType == .textGeneration {
                            let data = src.decodeData(TextGenerationData.self)
                            lines.append("      src output length: \(data?.executionOutput.count ?? -1)")
                            lines.append("      src output: \"\(data?.executionOutput.prefix(100) ?? "nil")\"")
                        }
                        if src.nodeType == .textInput {
                            let data = src.decodeData(TextInputData.self)
                            lines.append("      src text: \"\(data?.text ?? "nil")\"")
                        }
                    } else {
                        lines.append("      sourceNode: nil")
                    }
                }
            }
            if node.nodeType == .textGeneration {
                let data = node.decodeData(TextGenerationData.self)
                lines.append("    status: \(data?.executionStatus.rawValue ?? "nil")")
                lines.append("    output length: \(data?.executionOutput.count ?? -1) chars")
                lines.append("    output: \"\(data?.executionOutput.prefix(200) ?? "nil")\"")
                if let error = data?.executionError {
                    lines.append("    error: \(error)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .font(.system(size: 10, weight: .bold))
                        Text("Debug Console")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(flow.edges.count) edges, \(flow.nodes.count) nodes")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(debugText, forType: .string)
                    #else
                    UIPasteboard.general.string = debugText
                    #endif
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(copied ? .green : .blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.15))

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Edges info
                        Text("EDGES:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)

                        if flow.edges.isEmpty {
                            Text("  (no edges)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(flow.edges) { edge in
                                edgeDebugRow(edge)
                            }
                        }

                        Divider().background(Color.gray.opacity(0.3))

                        // Nodes info
                        Text("NODES:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)

                        ForEach(flow.nodes) { node in
                            nodeDebugRow(node)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(height: 150)
                .background(Color(white: 0.1))
            }
        }
        .background(Color(white: 0.12))
    }

    @ViewBuilder
    private func edgeDebugRow(_ edge: FlowEdge) -> some View {
        let sourceInfo = edge.sourceNode.map { "\($0.label) [\($0.nodeType.rawValue)]" } ?? "nil"
        let targetInfo = edge.targetNode.map { "\($0.label) [\($0.nodeType.rawValue)]" } ?? "nil"

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("Edge:")
                    .foregroundStyle(.green)
                Text("\(edge.sourceHandle) → \(edge.targetHandle)")
                Text("(\(edge.dataType.rawValue))")
                    .foregroundStyle(.yellow)
            }
            HStack(spacing: 4) {
                Text("  sourceNode:")
                    .foregroundStyle(.secondary)
                Text(sourceInfo)
                    .foregroundStyle(edge.sourceNode == nil ? .red : .white)
            }
            HStack(spacing: 4) {
                Text("  targetNode:")
                    .foregroundStyle(.secondary)
                Text(targetInfo)
                    .foregroundStyle(edge.targetNode == nil ? .red : .white)
            }
        }
        .font(.system(size: 10, design: .monospaced))
    }

    @ViewBuilder
    private func nodeDebugRow(_ node: FlowNode) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(node.label)")
                    .foregroundStyle(.white)
                Text("[\(node.nodeType.rawValue)]")
                    .foregroundStyle(.gray)
            }
            HStack(spacing: 4) {
                Text("  incomingEdges: \(node.incomingEdges.count)")
                    .foregroundStyle(node.incomingEdges.isEmpty ? .orange : .green)
                Text("  outgoingEdges: \(node.outgoingEdges.count)")
                    .foregroundStyle(node.outgoingEdges.isEmpty ? .orange : .green)
            }

            // Show incoming edge details for preview nodes
            if node.nodeType == .previewOutput && !node.incomingEdges.isEmpty {
                ForEach(node.incomingEdges) { edge in
                    HStack(spacing: 4) {
                        Text("    ← from:")
                            .foregroundStyle(.secondary)
                        if let src = edge.sourceNode {
                            Text("\(src.label)")
                                .foregroundStyle(.cyan)
                            // Show source data if text generation
                            if src.nodeType == .textGeneration {
                                let data = src.decodeData(TextGenerationData.self)
                                Text("output: \"\(data?.executionOutput.prefix(30) ?? "nil")...\"")
                                    .foregroundStyle(.yellow)
                            }
                        } else {
                            Text("nil")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .font(.system(size: 10, design: .monospaced))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Flow.self, FlowNode.self, FlowEdge.self], inMemory: true)
}
