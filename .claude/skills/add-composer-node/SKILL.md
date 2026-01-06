---
name: add-composer-node
description: This skill should be used when the user asks to "add a node", "create a new node", "implement a node type", "add a custom node", "new node for canvas", or mentions NodeDefinition, NodeRegistry, or adding nodes to the flow canvas. Provides workflow and templates for implementing new nodes in Composer Native.
---

# Adding Nodes to Composer Native

Composer uses a **protocol-oriented node system** where each node is a self-contained enum conforming to `NodeDefinition`. The protocol encapsulates all node behavior: metadata, ports, UI, and execution logic.

## Architecture Overview

| Component | Purpose |
|-----------|---------|
| `NodeDefinition` protocol | Defines node identity, ports, view, and execution |
| `NodeRegistry` | Type-erased storage for all node definitions |
| `NodeType` enum | Exhaustive list of node types (persisted to SwiftData) |
| `PortID` constants | Stable port identifiers (persisted in FlowEdge) |
| `FlowNode` | SwiftData model storing node position and JSON-encoded data |

## 5-Step Workflow

### Step 1: Add NodeType Case

**File:** `composer/Models/NodeType.swift`

Add a new case to the `NodeType` enum:

```swift
enum NodeType: String, Codable, CaseIterable, Sendable {
    case textInput
    case textGeneration
    case previewOutput
    case myNewNode  // ← Add here
}
```

**Critical:** This enum is persisted to SwiftData. Never rename or remove existing cases.

### Step 2: Add Port ID Constants

**File:** `composer/NodeSystem/PortID.swift`

Add stable port identifiers:

```swift
// MARK: - MyNewNode

/// MyNewNode input port
static let myNewNodeInput = "my-new-node.input"

/// MyNewNode output port
static let myNewNodeOutput = "my-new-node.output"
```

**Naming convention:** `<node-name>.<direction>.<port-name>`

Examples:
- `text-input.output` (single output)
- `text-gen.input.prompt` (multiple inputs)
- `text-gen.input.system`

**Critical:** Port IDs are persisted in `FlowEdge.sourceHandle` and `.targetHandle`. Never change existing IDs—only add new ones.

### Step 3: Create Node Definition File

**Directory:** `composer/NodeSystem/Nodes/<Category>/`

Categories:
- `Input/` — Data source nodes
- `LLM/` — AI/language model nodes
- `Transform/` — Data transformation nodes
- `Output/` — Display/export nodes

Create file: `composer/NodeSystem/Nodes/<Category>/<NodeName>Node.swift`

Copy the appropriate template from `examples/`:
- **Simple node** (pass-through): `examples/SimpleNode.swift`
- **Executable node** (async API calls): `examples/ExecutableNode.swift`

### Step 4: Register in NodeRegistry

**File:** `composer/NodeSystem/NodeRegistry.swift`

Add registration in the `definitions` dictionary (around line 99):

```swift
private static let definitions: [NodeType: AnyNodeDefinition] = {
    var registry: [NodeType: AnyNodeDefinition] = [:]
    register(TextInputNode.self, in: &registry)
    register(TextGenerationNode.self, in: &registry)
    register(PreviewOutputNode.self, in: &registry)
    register(MyNewNode.self, in: &registry)  // ← Add here
    return registry
}()
```

### Step 5: Add to UI Menu

**File:** `composer/ContentView.swift`

Add a button to the "Add Node" menu (around line 142):

```swift
Menu {
    // ... existing buttons ...

    Button {
        addNode(.myNewNode, to: flow)
    } label: {
        Label("My New Node", systemImage: NodeType.myNewNode.icon)
    }

    // ... more buttons ...
} label: {
    Label("Add Node", systemImage: "plus.rectangle")
}
```

**Note:** Place the button in logical order by category (inputs first, then LLM, then outputs).

## Port Data Types

| Type | Use Case | Wire Color |
|------|----------|------------|
| `.string` | Text data | Soft azure |
| `.image` | Image (Data blob) | Lavender |
| `.audio` | Audio (Data blob) | Electric mint |
| `.pulse` | Trigger signal (no payload) | Apricot |

Ports connect only when types match. Define ports in the node's `inputPorts` and `outputPorts` arrays:

```swift
static let inputPorts: [PortDefinition] = [
    PortDefinition(
        id: PortID.myNewNodeInput,
        label: "Input",
        dataType: .string,
        isRequired: true
    )
]
```

## Node Categories

| Category | Description | Order |
|----------|-------------|-------|
| `.input` | Data sources | 0 |
| `.llm` | Language models | 1 |
| `.transform` | Data transformation | 2 |
| `.controlFlow` | Branching, loops | 3 |
| `.integration` | External services | 4 |
| `.output` | Display, export | 5 |

## Quick Decisions

**Simple vs Executable:**
- `isExecutable = false` — Node passes data through (TextInput, PreviewOutput)
- `isExecutable = true` — Node performs async work (TextGeneration, API calls)

**When to add execution status:**
Only executable nodes need `executionStatus`, `executionOutput`, `executionError` in their NodeData struct.

## Templates

### Simple Node (Pass-Through)

Copy `examples/SimpleNode.swift` for nodes that:
- Store user input
- Transform data synchronously
- Display connected values

### Executable Node (Async)

Copy `examples/ExecutableNode.swift` for nodes that:
- Make API calls
- Perform async operations
- Need progress/error states

## Additional Resources

### Reference Files

- **`references/swiftdata-patterns.md`** — Critical iOS SwiftData patterns to avoid crashes and stale data

### Example Files

- **`examples/SimpleNode.swift`** — Complete template for pass-through nodes
- **`examples/ExecutableNode.swift`** — Complete template for async executable nodes

## Existing Node Examples

Study these files for real implementations:

| Node | Type | File |
|------|------|------|
| TextInput | Simple | `NodeSystem/Nodes/Input/TextInputNode.swift` |
| TextGeneration | Executable | `NodeSystem/Nodes/LLM/TextGenerationNode.swift` |
| ImageGeneration | Executable | `NodeSystem/Nodes/LLM/ImageGenerationNode.swift` |
| PreviewOutput | Simple | `NodeSystem/Nodes/Output/PreviewOutputNode.swift` |

## Calling ExecutionService (API Nodes)

For nodes that call the backend API (like TextGeneration, ImageGeneration), use `ExecutionService.shared.execute()`.

### Function Signature

```swift
func execute(
    nodeType: String,        // e.g., "text-generation", "image-generation"
    inputs: [String: Any],   // Parameters (use correct types!)
    provider: String,        // e.g., "openai", "google", "anthropic"
    model: String            // e.g., "gpt-5.2", "claude-sonnet-4-5"
) -> AsyncThrowingStream<ExecutionEvent, Error>
```

### CRITICAL: API Body Differences

Different node types have **different API body structures**. The ExecutionService handles this automatically, but you must use correct types:

| Node Type | Body Structure | Notes |
|-----------|----------------|-------|
| `text-generation` | Nested `inputs` dict | `inputs.prompt`, `inputs.system` |
| `image-generation` | Flat parameters | `input`, `size`, `partialImages` at top level |

### Type Requirements

**`partialImages` and other numeric params MUST be integers:**

```swift
// ✅ CORRECT - integers are integers
let apiInputs: [String: Any] = [
    "prompt": prompt,
    "partialImages": 3,  // Int, not String
    "size": "1024x1024"  // String is fine
]

// ❌ WRONG - will cause HTTP 500
let apiInputs: [String: String] = [
    "prompt": prompt,
    "partialImages": "3"  // String causes API error!
]
```

### Example Usage

```swift
let stream = await ExecutionService.shared.execute(
    nodeType: "image-generation",
    inputs: [
        "prompt": promptText,
        "size": "1024x1024",
        "quality": "low",
        "outputFormat": "webp",
        "partialImages": 3  // Must be Int!
    ],
    provider: "openai",
    model: "gpt-5.2"
)

for try await event in stream {
    switch event {
    case .image(let data, let mimeType):
        // Handle final image
    case .partialImage(let data, let index, let mimeType):
        // Handle partial image during generation
    case .text(let text):
        // Handle text output
    case .error(let message):
        // Handle error
    case .done:
        break
    default:
        break
    }
}
```

## Validation After Implementation

1. Build with `mcp__XcodeBuildMCP__build_sim` or `build_macos`
2. Add node to canvas via node picker
3. Verify ports appear correctly
4. Connect to other nodes
5. Run flow and check execution (for executable nodes)
