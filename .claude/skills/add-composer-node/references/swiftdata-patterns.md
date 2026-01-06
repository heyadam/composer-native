# iOS SwiftData Patterns for Nodes

Critical patterns to avoid crashes and stale data on iOS/iPadOS. macOS is more forgiving, but always code for iOS behavior.

## The Stale Flow Problem

When SwiftUI recreates a view, the view model may hold a **stale** `Flow` reference. On iOS, relationship arrays like `flow.nodes` become empty while direct object references remain valid.

### Rule: Pass Objects, Not IDs

For single object mutations where the view has a reference:

```swift
// ❌ BAD - flow.nodes may be empty on iOS
func updateNode(_ nodeId: UUID) {
    guard let node = flow.nodes.first(where: { $0.id == nodeId }) else {
        return  // FAILS on iOS!
    }
    node.someProperty = newValue
}

// ✅ GOOD - pass object directly from view
func updateNode(_ node: FlowNode) {
    node.someProperty = newValue
    node.flow?.touch()  // Use object's relationship for fresh flow
}
```

### Rule: Fetch from ModelContext for Bulk Operations

When only UUIDs are available or for bulk operations:

```swift
// ✅ GOOD - fetch fresh from ModelContext
@MainActor
static func execute(
    node: FlowNode,
    inputs: NodeInputs,
    context: ExecutionContext
) async throws -> NodeOutputs {
    // Fetch fresh node
    let nodeId = node.id
    let predicate = #Predicate<FlowNode> { $0.id == nodeId }

    guard let freshNodes = try? context.modelContext.fetch(
        FetchDescriptor(predicate: predicate)
    ), let freshNode = freshNodes.first else {
        // Fallback to passed node
        return processNode(node)
    }

    return processNode(freshNode)
}
```

## Always Touch After Mutations

After modifying node data, notify SwiftUI:

```swift
node.encodeData(MyNodeData(value: newValue))
node.flow?.touch()  // Critical for SwiftUI updates
```

The `touch()` method updates the flow's timestamp, triggering SwiftUI observation.

## Port ID Stability

Port IDs are persisted in `FlowEdge.sourceHandle` and `.targetHandle`:

- **Never rename** existing port IDs
- **Never delete** port IDs that may be in use
- Only **add new** port IDs

If a port ID changes, existing edges will fail to connect.

## @State Initialization Guards

When using `@State` with initialization guards, always set the flag to `true` even for empty initial values:

```swift
@State private var text: String = ""
@State private var hasInitializedText = false

private func initializeTextIfNeeded() {
    guard !hasInitializedText else { return }

    if let content = viewModel?.textContent {
        text = content
    } else if let storedData = node.decodeData(MyNodeData.self) {
        text = storedData.text
    }
    // ✅ CRITICAL: Always set flag, even for empty nodes
    hasInitializedText = true
}

.onChange(of: text) { _, newValue in
    // Guard prevents saving during init sync
    guard hasInitializedText else { return }
    node.encodeData(MyNodeData(text: newValue))
    node.flow?.touch()
}
```

**Symptom if missing:** User input silently ignored on first flow run; works on second run.

## Safe Cascade Delete

Use `modelContext.safeDelete()` for objects with relationships:

```swift
// ❌ BAD - may crash with _FullFutureBackingData
modelContext.delete(flow)

// ✅ GOOD - materializes relationships first
modelContext.safeDelete(flowId: flow.id)
modelContext.safeDelete(nodeIds: selectedNodeIds)
modelContext.safeDelete(edgeIds: selectedEdgeIds)
```

See `Extensions/ModelContext+SafeDelete.swift` for implementation.

## Node Data Encoding/Decoding

All node-specific data is stored as JSON in `FlowNode.dataJSON`:

```swift
// Decode
let data = node.decodeData(MyNodeData.self) ?? MyNode.defaultData

// Encode
node.encodeData(MyNodeData(value: newValue))
```

The `NodeData` struct must conform to `Codable`.

## Summary Checklist

- [ ] Pass objects directly when view has reference
- [ ] Fetch from ModelContext in execute() methods
- [ ] Call `node.flow?.touch()` after mutations
- [ ] Never modify existing port IDs
- [ ] Set `@State` init flags even for empty values
- [ ] Use `safeDelete()` for cascade deletes
