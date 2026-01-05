# SwiftData View Model Pattern

## The Stale Flow Problem

When using SwiftData with view models, relationship arrays (like `flow.nodes`) stored in a view model can become **stale or empty** on iOS/iPadOS while the view's references remain valid.

### Why This Happens

1. `FlowCanvasView` receives a `Flow` object and creates a view model in `.task`
2. SwiftUI may recreate the view with a **fresh** `Flow` object from SwiftData
3. The view model still holds the **old** `Flow` reference
4. The old `Flow`'s relationship arrays (`nodes`, `edges`) become faulted/empty
5. But nodes passed directly to child views remain valid references

### Platform Behavior

| Platform | Behavior |
|----------|----------|
| macOS | View recreation is rare; stale references usually work |
| iOS/iPadOS | View recreation is aggressive; stale references fail silently |

**Always code for iOS behavior** - if it works on iOS, it works everywhere.

---

## Pattern 1: Pass Objects, Not IDs

For **single object mutations** where the view already has a reference to the object.

**DON'T** look up objects in view model methods:
```swift
// BAD - flow.nodes may be empty on iOS
func endNodeDrag(_ nodeId: UUID) {
    guard let node = flow.nodes.first(where: { $0.id == nodeId }) else {
        return // FAILS on iOS - flow.nodes is empty!
    }
    node.position = newPosition
}
```

**DO** pass objects directly from the view:
```swift
// GOOD - node reference from view is always valid
func endNodeDrag(_ node: FlowNode) {
    node.position = newPosition
    node.flow?.touch() // Use object's relationship for fresh flow
}
```

### When to Use
- View has the object reference (e.g., `ForEach(nodes) { node in ... }`)
- Single object being modified
- Examples: `endNodeDrag(_:)`, updating a single node's properties

---

## Pattern 2: Fetch from ModelContext

For **bulk operations** or when you only have IDs (not object references).

**DON'T** use relationship arrays:
```swift
// BAD - flow.nodes is stale on iOS
func deleteNodes(_ ids: Set<UUID>) {
    for id in ids {
        if let node = flow.nodes.first(where: { $0.id == id }) {
            modelContext.delete(node) // Never reached - flow.nodes is empty!
        }
    }
}
```

**DO** fetch fresh objects from ModelContext:
```swift
// GOOD - fetches live objects from SwiftData
func deleteNodes(_ ids: Set<UUID>) {
    let predicate = #Predicate<FlowNode> { node in
        ids.contains(node.id)
    }
    guard let nodesToDelete = try? modelContext.fetch(FetchDescriptor(predicate: predicate)),
          !nodesToDelete.isEmpty else { return }

    // Get fresh flow reference from fetched object
    guard let freshFlow = nodesToDelete.first?.flow else { return }

    for node in nodesToDelete {
        modelContext.delete(node)
    }
    freshFlow.touch() // Notify SwiftUI of changes
}
```

### Key Points
1. **Use `FetchDescriptor` with `#Predicate`** to query ModelContext directly
2. **Get fresh flow from fetched objects** - use `node.flow` or `edge.flow`, not `self.flow`
3. **Call `touch()` on the fresh flow** to trigger SwiftUI updates

### When to Use
- Bulk operations (delete multiple nodes/edges)
- Only have UUIDs, not object references
- Creating relationships between objects (e.g., `createEdge`)
- Examples: `deleteNodes(_:)`, `deleteEdges(_:)`, `createEdge(from:to:)`

---

## Pattern 3: Fresh Flow for Relationships

When creating new objects with relationships, use fresh flow references.

**DON'T** use the ViewModel's flow:
```swift
// BAD - self.flow may be stale
func createEdge(from source: ConnectionPoint, to target: ConnectionPoint) {
    let edge = FlowEdge(...)
    edge.flow = self.flow // Stale flow - edge won't appear in UI!
    edge.sourceNode = sourceNode
}
```

**DO** get fresh flow from fetched objects:
```swift
// GOOD - use relationship from fresh object
func createEdge(from source: ConnectionPoint, to target: ConnectionPoint) {
    // Fetch nodes fresh from context
    let sourceNodes = try? modelContext.fetch(FetchDescriptor(predicate: sourcePredicate))
    guard let sourceNode = sourceNodes?.first,
          let freshFlow = sourceNode.flow else { return }

    let edge = FlowEdge(...)
    edge.flow = freshFlow // Fresh flow - edge appears immediately!
    edge.sourceNode = sourceNode

    freshFlow.touch()
}
```

---

## Quick Reference

| Scenario | Pattern | Example |
|----------|---------|---------|
| View has object reference | Pass object directly | `endNodeDrag(node)` |
| Only have UUID(s) | Fetch from ModelContext | `deleteNodes(ids)` |
| Creating relationships | Fresh flow from fetched object | `createEdge(...)` |
| Notifying UI of changes | `object.flow?.touch()` | After any mutation |

## Key Files

- `FlowCanvasViewModel.swift` - All patterns demonstrated
  - `endNodeDrag(_:)` - Pattern 1 (pass object)
  - `deleteNodes(_:)` - Pattern 2 (fetch from context)
  - `createEdge(from:to:)` - Pattern 3 (fresh flow for relationships)
- `NodeContainerView.swift` - Passes `node` directly to view model
- `CanvasState.swift` - Port registry (not affected by stale flow)

## Symptoms of Stale Flow

If you see these issues **only on iOS/iPadOS**:
- Node/edge operations silently fail
- `flow.nodes.first(where:)` returns nil
- Edges created but don't appear
- Delete doesn't work despite correct logic
- Console shows "nodeNotFound" or similar

**Solution**: Apply the patterns above - fetch from ModelContext and use fresh flow references.
