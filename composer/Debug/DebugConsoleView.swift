//
//  DebugConsoleView.swift
//  composer
//
//  Debug console for inspecting flow state
//

import SwiftUI

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
                            let data = src.decodeData(TextGenerationNodeData.self)
                            lines.append("      src output length: \(data?.executionOutput.count ?? -1)")
                            lines.append("      src output: \"\(data?.executionOutput.prefix(100) ?? "nil")\"")
                        }
                        if src.nodeType == .textInput {
                            let data = src.decodeData(TextInputNodeData.self)
                            lines.append("      src text: \"\(data?.text ?? "nil")\"")
                        }
                    } else {
                        lines.append("      sourceNode: nil")
                    }
                }
            }
            if node.nodeType == .textGeneration {
                let data = node.decodeData(TextGenerationNodeData.self)
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
                                let data = src.decodeData(TextGenerationNodeData.self)
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
