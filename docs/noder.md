# Modular Node System Architecture

**Status:** ✅ **COMPLETE** - All phases implemented and verified

**Goal:** Create a "React Flow for Swift" - modular, extensible node system where adding a new node requires minimal file changes.

## Key Design Decisions

1. **NodeViewModel remains** - Keeps transient UI state (measuredSize, isEditing) but loses type-specific accessors like `textContent`
2. **AnyView for type erasure** - Acceptable trade-off since nodes don't recreate rapidly
3. **iOS SwiftData patterns** - ExecutionContext fetches fresh objects from ModelContext (per `.claude/rules/swiftdata-view-model.md`)
4. **Ports defined in nodes** - More cohesive than separate NodePortSchemas file
5. **getOutputValue() method** - Nodes expose their output values via protocol, so PreviewOutputNode doesn't need switch statements on every node type

---

## Architecture Overview

### Core Concept: NodeDefinition Protocol

Each node type is a self-contained implementation of `NodeDefinition`:

```swift
protocol NodeDefinition {
    static var nodeType: NodeType { get }
    associatedtype NodeData: Codable & Sendable
    static var defaultData: NodeData { get }

    // Display
    static var displayName: String { get }
    static var icon: String { get }
    static var category: NodeCategory { get }

    // Ports (static, stable IDs)
    static var inputPorts: [PortDefinition] { get }
    static var outputPorts: [PortDefinition] { get }

    // View
    associatedtype ContentView: View
    @MainActor static func makeContentView(node:state:connectionViewModel:) -> ContentView

    // Execution
    static var isExecutable: Bool { get }
    @MainActor static func execute(node:inputs:context:) async throws -> NodeOutputs

    // Output value access (for preview nodes to read data without knowing node types)
    @MainActor static func getOutputValue(node: FlowNode, portId: String) -> NodeValue?
}
```

### NodeRegistry (Static, Type-Safe)

```swift
enum NodeRegistry {
    private static let definitions: [NodeType: AnyNodeDefinition] = {
        var registry: [NodeType: AnyNodeDefinition] = [:]
        register(TextInputNode.self, in: &registry)
        register(TextGenerationNode.self, in: &registry)
        register(PreviewOutputNode.self, in: &registry)
        // Future: register(ConditionalNode.self, ...)
        return registry
    }()

    static func makeContentView(for node: FlowNode, ...) -> AnyView
    static func execute(node:inputs:context:) async throws -> NodeOutputs
    static func inputPorts(for type: NodeType) -> [PortDefinition]
    static func getOutputValue(node: FlowNode, portId: String) -> NodeValue?  // For preview nodes
    static func canConnect(from source: PortID, to target: PortID) -> Bool   // Port compatibility
}
```

---

## File Structure

```
composer/
├── NodeSystem/
│   ├── NodeDefinition.swift       # Core protocol
│   ├── NodeRegistry.swift         # Static registry
│   ├── NodeCategory.swift         # Category enum (Input, LLM, ControlFlow, etc.)
│   ├── ExecutionTypes.swift       # NodeInputs, NodeOutputs, NodeValue, ExecutionContext
│   ├── PortID.swift               # All stable port ID constants
│   └── Nodes/
│       ├── Input/
│       │   └── TextInputNode.swift
│       ├── LLM/
│       │   └── TextGenerationNode.swift
│       ├── ControlFlow/           # Future
│       ├── Transform/             # Future
│       ├── Integration/           # Future
│       └── Output/
│           └── PreviewOutputNode.swift
```

---

## Implementation Phases

### Phase 1: Add Infrastructure (Non-Breaking) ✅

| Step | File | Action | Status |
|------|------|--------|--------|
| 1.1 | `NodeSystem/NodeDefinition.swift` | Create core protocol | ✅ |
| 1.2 | `NodeSystem/ExecutionTypes.swift` | Create NodeInputs, NodeOutputs, NodeValue, ExecutionContext, ExecutionStatus | ✅ |
| 1.3 | `NodeSystem/NodeCategory.swift` | Create category enum | ✅ |
| 1.4 | `NodeSystem/PortID.swift` | Move stable port IDs from NodePortSchemas | ✅ |
| 1.5 | `NodeSystem/NodeRegistry.swift` | Create registry with type-erased wrappers, include `canConnect(from:to:)` | ✅ |

### Phase 2: Migrate Existing Nodes ✅

| Step | File | Action | Status |
|------|------|--------|--------|
| 2.1 | `NodeSystem/Nodes/Input/TextInputNode.swift` | Create, move TextInputData + view logic | ✅ |
| 2.2 | `NodeSystem/Nodes/LLM/TextGenerationNode.swift` | Create, move TextGenerationData + view + execution | ✅ |
| 2.3 | `NodeSystem/Nodes/Output/PreviewOutputNode.swift` | Create, move view logic | ✅ |
| 2.4 | `NodeRegistry.swift` | Register all 3 nodes | ✅ |

### Phase 3: Update Consumers ✅

> **Ordering Note:** Steps 3.1-3.3 must complete before 3.4-3.5. Step 3.4 (remove data structs) depends on 3.2 and 3.3 completing first.

| Step | File | Action | Status |
|------|------|--------|--------|
| 3.1 | `Nodes/NodeContainerView.swift` | Remove switch, use `NodeRegistry.makeContentView()` | ✅ |
| 3.2 | `ViewModels/FlowCanvasViewModel.swift` | Update execution to use `NodeRegistry.execute()`, remove TextInputData/TextGenerationData refs | ✅ |
| 3.3 | `NodeSystem/Nodes/Output/PreviewOutputNode.swift` | Update `getConnectedData()` to use `NodeRegistry.getOutputValue()` instead of switch on nodeType | ✅ |
| 3.4 | `Models/FlowNode.swift` | Delegate inputPorts/outputPorts to registry, remove data structs (depends on 3.2, 3.3) | ✅ |
| 3.5 | `Models/NodeType.swift` | Delegate displayName/icon to registry | ✅ |
| 3.6 | `ViewModels/ConnectionViewModel.swift` | Update to use `NodeRegistry.canConnect()` | ✅ |
| 3.7 | `Debug/DebugConsoleView.swift`, `DebugLogger.swift` | Update to use new data type names | ✅ |

### Phase 4: Cleanup ✅

| Step | File | Action | Status |
|------|------|--------|--------|
| 4.1 | `Models/NodePortSchemas.swift` | Delete (replaced by PortID.swift + node definitions) | ✅ |
| 4.2 | `Nodes/TextInputNodeView.swift` | Delete (moved to TextInputNode.swift) | ✅ |
| 4.3 | `Nodes/TextGenerationNodeView.swift` | Delete (moved to TextGenerationNode.swift) | ✅ |
| 4.4 | `Nodes/PreviewOutputNodeView.swift` | Delete (moved to PreviewOutputNode.swift) | ✅ |

---

## Key Files to Modify

| File | Changes |
|------|---------|
| `composer/Nodes/NodeContainerView.swift` | Remove switch statement → use registry |
| `composer/ViewModels/FlowCanvasViewModel.swift` | Replace execution switch → registry dispatch |
| `composer/ViewModels/NodeViewModel.swift` | Remove `textContent` accessor (type-specific), keep transient state |
| `composer/Models/FlowNode.swift` | Remove TextInputData, TextGenerationData; delegate to registry |
| `composer/Models/NodeType.swift` | Keep enum cases, delegate displayName/icon to registry |
| `composer/Models/NodePortSchemas.swift` | **Delete** (replaced) |

## Key Files to Create

| File | Purpose |
|------|---------|
| `composer/NodeSystem/NodeDefinition.swift` | Core protocol |
| `composer/NodeSystem/NodeRegistry.swift` | Static registry + AnyNodeDefinition wrapper + `canConnect(from:to:)` |
| `composer/NodeSystem/ExecutionTypes.swift` | NodeInputs, NodeOutputs, NodeValue, ExecutionContext, ExecutionStatus |
| `composer/NodeSystem/NodeCategory.swift` | Category enum for node picker organization |
| `composer/NodeSystem/PortID.swift` | All stable port ID constants |
| `composer/NodeSystem/Nodes/Input/TextInputNode.swift` | Self-contained text input node |
| `composer/NodeSystem/Nodes/LLM/TextGenerationNode.swift` | Self-contained text generation node |
| `composer/NodeSystem/Nodes/Output/PreviewOutputNode.swift` | Self-contained preview output node |

---

## Adding a New Node (Post-Migration)

**1. Add enum case** to `NodeType.swift`:
```swift
case httpRequest
```

**2. Create node file** (e.g., `NodeSystem/Nodes/Integration/HTTPRequestNode.swift`):
```swift
enum HTTPRequestNode: NodeDefinition {
    static let nodeType: NodeType = .httpRequest
    static let displayName = "HTTP Request"
    static let icon = "network"
    static let category: NodeCategory = .integration

    struct NodeData: Codable, Sendable { ... }
    static var inputPorts: [PortDefinition] { ... }
    static var outputPorts: [PortDefinition] { ... }
    static func makeContentView(...) -> some View { ... }
    static func execute(...) async throws -> NodeOutputs { ... }
}
```

**3. Register** in `NodeRegistry.swift`:
```swift
register(HTTPRequestNode.self, in: &registry)
```

**Done.** 2 files modified, 1 file created.

---

## Control Flow Support

Control flow nodes (conditionals, loops) use active branch tracking:

```swift
// In ConditionalNode.execute():
var outputs = NodeOutputs()
if conditionResult {
    outputs["conditional.true"] = .string(input)
} else {
    outputs["conditional.false"] = .string(input)
}
return outputs
```

The flow executor only follows edges from output ports that have values.

---

## Verification Steps

After each phase, run:
```bash
mcp__XcodeBuildMCP__build_macos  # Quick compilation check
```

After Phase 3 (consumers updated):
```bash
mcp__XcodeBuildMCP__build_run_sim  # Visual verification
mcp__XcodeBuildMCP__test_macos     # Run existing tests
```

---

## Breaking Changes

**None.** Migration is fully incremental:
- SwiftData models unchanged (FlowNode, FlowEdge, Flow)
- NodeType enum cases unchanged
- Port IDs preserved
- Existing flows work throughout migration

---

## Implementation Notes

**Completed:** January 6, 2026

### Swift 6 Concurrency Adjustment

The original spec called for `NodeData: Codable & Sendable`. However, Swift 6's strict concurrency checking causes issues with `Codable` conformance for types nested inside `@MainActor` enums. The error:
```
Main actor-isolated conformance of 'NodeData' to 'Decodable' cannot satisfy conformance requirement for a 'Sendable' type parameter
```

**Solution:** NodeData structs are defined *outside* the enum (as top-level types like `TextInputNodeData`) and the `Sendable` requirement was removed from the protocol. This is safe because:
1. Node data is only accessed on `@MainActor`
2. The `NodeValue` enum (which flows between nodes) remains `Sendable`

### Additional Consumers Updated

Beyond the planned files, these also needed updating:
- `ConnectionViewModel.swift` - Used `NodePortSchemas.canConnect()`
- `DebugConsoleView.swift` / `DebugLogger.swift` - Referenced old data type names

### NodeViewModel.textContent Retained

The spec suggested removing `textContent` from NodeViewModel, but it was retained and updated to use `TextInputNodeData`. This accessor is used by `TextInputNode.ContentView` for `@Bindable` text editing.
