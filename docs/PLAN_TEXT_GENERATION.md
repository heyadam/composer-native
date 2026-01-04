# Plan: Text Generation Node & Flow Execution

## Goal
Add a text generation node and wire up flow execution to run flows end-to-end.

## Architecture

The Composer backend (`/api/execute`) handles all LLM provider logic. The native app only needs:
- HTTP client to POST requests
- NDJSON stream parser for responses
- API keys passed in request body

```
[Text Input] → prompt → [Text Generation] → output → [Preview Output]
                              ↓
                        POST /api/execute
                              ↓
                        NDJSON stream
                              ↓
                        Update node UI
```

---

## Implementation Steps

### 1. Add TextGeneration Node Type

**Modify:** `composer/Models/NodeType.swift`
```swift
case textGeneration
```

**Modify:** `composer/Models/NodePortSchemas.swift`
```swift
case .textGeneration:
    return [
        PortDefinition(id: "text-gen.input.prompt", label: "Prompt", dataType: .string, isRequired: true),
        PortDefinition(id: "text-gen.input.system", label: "System", dataType: .string, isRequired: false)
    ]
// Output ports:
case .textGeneration:
    return [
        PortDefinition(id: "text-gen.output", label: "Output", dataType: .string, isRequired: false)
    ]
```

### 2. Node Data Model

**Create:** `composer/Models/NodeData/TextGenerationData.swift`
```swift
struct TextGenerationData: Codable {
    var provider: String = "openai"
    var model: String = "gpt-4o"
    var executionStatus: ExecutionStatus = .idle
    var executionOutput: String = ""
    var executionError: String?
}

enum ExecutionStatus: String, Codable {
    case idle, running, success, error
}
```

### 3. Node View

**Create:** `composer/Nodes/TextGenerationNodeView.swift`
- Status indicator (idle/running/success/error)
- Streaming output preview (scrollable text)
- Error message display

**Modify:** `composer/Nodes/NodeFrame.swift`
- Route `.textGeneration` to `TextGenerationNodeView`

### 4. API Key Storage

**Create:** `composer/Services/APIKeyStorage.swift`
```swift
import Security

actor APIKeyStorage {
    static let shared = APIKeyStorage()

    func setKey(_ key: String, for provider: String) throws
    func getKey(for provider: String) -> String?
    func deleteKey(for provider: String) throws
}
```

Uses Keychain Services for secure storage.

### 5. Settings UI

**Create:** `composer/Views/SettingsView.swift`
- SecureField for OpenAI, Anthropic, Google keys
- Checkmark indicator when key is saved
- Presented from toolbar gear icon

**Modify:** `composer/ContentView.swift`
- Add gear icon to toolbar
- Present SettingsView as sheet

### 6. Execution Service

**Create:** `composer/Services/ExecutionService.swift`
```swift
actor ExecutionService {
    static let shared = ExecutionService()

    func execute(
        nodeType: String,
        inputs: [String: String],
        provider: String,
        model: String
    ) -> AsyncThrowingStream<ExecutionEvent, Error>
}
```

- POST to `https://composer.design/api/execute`
- Request body matches backend format
- Returns async stream of events

### 7. NDJSON Parser

**Create:** `composer/Services/NDJSONParser.swift`
```swift
enum ExecutionEvent {
    case text(String)
    case reasoning(String)
    case usage(promptTokens: Int, completionTokens: Int)
    case error(String)
    case done
}

struct NDJSONParser {
    static func parse(line: String) -> ExecutionEvent?
}
```

### 8. Flow Execution

**Modify:** `composer/ViewModels/FlowCanvasViewModel.swift`
```swift
func executeFlow() async {
    // 1. Topological sort nodes by edges
    // 2. For each node in order:
    //    - Gather inputs from connected nodes
    //    - Execute node
    //    - Store output for downstream nodes
    // 3. Update execution status on each node
}
```

### 9. Execute Button

**Modify:** `composer/Canvas/FlowCanvasView.swift`
- Add "Run" button to toolbar (play icon)
- Keyboard shortcut: ⌘R
- Disabled while execution in progress

---

## Files Summary

### Modify
| File | Change |
|------|--------|
| `Models/NodeType.swift` | Add `.textGeneration` case |
| `Models/NodePortSchemas.swift` | Define input/output ports |
| `Nodes/NodeFrame.swift` | Route to TextGenerationNodeView |
| `ViewModels/FlowCanvasViewModel.swift` | Add `executeFlow()` |
| `Canvas/FlowCanvasView.swift` | Add Run button |
| `ContentView.swift` | Add Settings button |

### Create
| File | Purpose |
|------|---------|
| `Models/NodeData/TextGenerationData.swift` | Node config + execution state |
| `Nodes/TextGenerationNodeView.swift` | Node UI with output preview |
| `Services/APIKeyStorage.swift` | Keychain wrapper |
| `Services/ExecutionService.swift` | API client |
| `Services/NDJSONParser.swift` | Stream parser |
| `Views/SettingsView.swift` | API key entry |

---

## API Request Format

```json
POST https://composer.design/api/execute
Content-Type: application/json

{
  "type": "text-generation",
  "inputs": {
    "prompt": "User message here",
    "system": "System instructions"
  },
  "provider": "openai",
  "model": "gpt-4o",
  "apiKeys": {
    "openai": "sk-..."
  }
}
```

## API Response Format (NDJSON)

```
{"type": "text", "content": "Hello"}
{"type": "text", "content": " world"}
{"type": "reasoning", "content": "Thinking..."}
{"type": "usage", "promptTokens": 10, "completionTokens": 20}
```

---

## MVP Scope

1. Text generation node with OpenAI GPT-4o (hardcoded)
2. Manual "Run" button (⌘R)
3. Settings UI for API keys (Keychain)
4. Basic error display

## Future Enhancements

- Provider/model selector in node UI
- Execution caching
- Parallel node execution
- Auto-run on input change
- Cancel execution
