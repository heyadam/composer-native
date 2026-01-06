# Composer Native

Universal macOS/iOS app for Composer - a visual AI workflow builder.

## Deployment Targets
- iOS 26+
- macOS 26+

## Building: Use XcodeBuildMCP

This project uses **XcodeBuildMCP** for all build, test, and simulator operations. The MCP server handles project/scheme detection automatically.

### Session Setup (First Time)

Before building, set session defaults so tools know which project and simulator to use:

```
mcp__XcodeBuildMCP__session-set-defaults
  - projectPath: /Users/adam/dev/composer-native/composer.xcodeproj
  - scheme: composer
  - simulatorName: iPhone 17 Pro (or desired simulator)
  - useLatestOS: true
```

**For iPad-specific issues**, use the iPad Pro 11-inch (M5) simulator:
```
mcp__XcodeBuildMCP__session-set-defaults
  - simulatorName: iPad Pro 11-inch (M5)
```

### Build Commands

| Task | MCP Tool |
|------|----------|
| Build for macOS | `mcp__XcodeBuildMCP__build_macos` |
| Build & run macOS | `mcp__XcodeBuildMCP__build_run_macos` |
| Build for iOS Simulator | `mcp__XcodeBuildMCP__build_sim` |
| Build & run on iOS Simulator | `mcp__XcodeBuildMCP__build_run_sim` |
| Run macOS tests | `mcp__XcodeBuildMCP__test_macos` |
| Run iOS Simulator tests | `mcp__XcodeBuildMCP__test_sim` |
| Clean build products | `mcp__XcodeBuildMCP__clean` |
| Show current settings | `mcp__XcodeBuildMCP__session-show-defaults` |

### Simulator Management

| Task | MCP Tool |
|------|----------|
| List available simulators | `mcp__XcodeBuildMCP__list_sims` |
| Boot simulator | `mcp__XcodeBuildMCP__boot_sim` |
| Open Simulator app | `mcp__XcodeBuildMCP__open_sim` |
| Take screenshot | `mcp__XcodeBuildMCP__screenshot` |
| Get UI hierarchy | `mcp__XcodeBuildMCP__describe_ui` |

### Runtime Log Capture

Capture logs from running app for debugging:

```
# Start capturing logs
mcp__XcodeBuildMCP__start_sim_log_cap(bundleId: "com.heyadam.composer")

# ... interact with app ...

# Stop and retrieve logs
mcp__XcodeBuildMCP__stop_sim_log_cap(logSessionId: <returned id>)
```

### On Build Failure

- **Auto-fix**: Missing imports, `await` keywords, simple typos
- **Ask first**: Architectural changes, ambiguous fixes
- **Mysterious failures**: Use `/axiom:fix-build` (see below)

## Build & Debug Troubleshooting

| Situation | Use |
|-----------|-----|
| Run a macOS build | `mcp__XcodeBuildMCP__build_macos` |
| Run an iOS build | `mcp__XcodeBuildMCP__build_sim` |
| Run tests | `mcp__XcodeBuildMCP__test_macos` or `test_sim` |
| Build fails with code errors | Read error output, auto-fix simple issues |
| Mysterious failures (no clear error, stale code, "No such module") | `/axiom:fix-build` or `mcp__XcodeBuildMCP__clean` |
| Builds are slow | `/axiom:optimize-build` |
| Runtime issues (execution, API, state) | Use `start_sim_log_cap` or read debug log |
| Verify new feature works | Build, run app, use `screenshot` or `describe_ui` |

**`/axiom:fix-build`** diagnoses environment issues (zombie processes, stale Derived Data, stuck simulators) that cause mysterious failures.

## Code Intelligence: Swift LSP

This project has the **Swift LSP plugin** installed, which provides language server features for Swift code navigation:

- **Symbol search** - Find types, functions, and properties by name
- **Go to definition** - Navigate to symbol declarations
- **Find references** - Locate all usages of a symbol
- **Code completion context** - Understand available APIs

Use standard Grep/Glob for quick searches, but the LSP provides semantic understanding of Swift code structure.

## Implementation Planning

For non-trivial features, create an implementation plan before writing code. After creating the plan, use the **plan-reviewer agent** to validate it.

### When to Create a Plan

- New features touching multiple files
- Architectural changes or refactoring
- Complex integrations (API, persistence, UI interactions)
- Any task where the approach isn't immediately obvious

### Plan Review Workflow

1. **Enter plan mode** with `EnterPlanMode` tool
2. **Explore the codebase** to understand existing patterns
3. **Write the plan** with step-by-step implementation steps
4. **Review with plan-reviewer agent** before coding:

```
Task(subagent_type: "plan-reviewer", prompt: "Review my implementation plan")
```

The plan-reviewer agent checks for:
- **Completeness** - Missing steps, edge cases, or error handling
- **Ordering** - Dependency issues between steps
- **Feasibility** - Steps that may be harder than they appear
- **Risk spots** - Changes that could break existing functionality

### Example

```
User: "Add offline flow caching with SwiftData"

1. Enter plan mode → explore codebase
2. Write plan:
   - Step 1: Create CachedFlow model
   - Step 2: Add sync logic to FlowCanvasViewModel
   - Step 3: Handle conflict resolution
   - ...
3. Run plan-reviewer agent → catches missing migration step
4. Update plan → exit plan mode
5. Implement with confidence
```

**Do NOT skip plan review for multi-file changes.** The reviewer catches issues that cause rework.

## Development: Axiom First, Context7 to Verify

**CRITICAL: Invoke Axiom skills BEFORE writing any iOS/Swift code.** Do not write implementation code until you've consulted the relevant skill. This ensures you use current APIs and patterns.

### Mandatory Skill Invocation

**Before implementing a feature:**
1. Identify which Axiom skill(s) apply to the task
2. Invoke the skill using the Skill tool (e.g., `Skill: axiom:swiftui-26-ref`)
3. Read the skill's guidance on current APIs and patterns
4. Only then write the implementation code

**Before writing tests:**
1. Invoke `axiom:ui-testing` for UI tests or `axiom:testing` for unit tests
2. Follow the skill's test patterns and assertions
3. Use `mcp__XcodeBuildMCP__test_macos` or `test_sim` to run tests

**Example workflow:**
```
User: "Add a new button with Liquid Glass styling"
→ Invoke axiom:liquid-glass skill
→ Read current Liquid Glass API patterns
→ Implement the button using skill guidance
→ Build with mcp__XcodeBuildMCP__build_run_sim (or build_run_macos)
→ Verify visually with mcp__XcodeBuildMCP__screenshot
```

### Apple Intelligence & iOS 26
- `foundation-models` - On-device AI with Foundation Models framework
- `foundation-models-ref` - Foundation Models API reference
- `app-intents-ref` - App Intents for Siri and Shortcuts
- `swiftui-26-ref` - New SwiftUI APIs in iOS 26/macOS 26

### UI & Design
- `liquid-glass` - Liquid Glass effects (WWDC 2025)
- `liquid-glass-ref` - Liquid Glass API reference
- `hig` / `hig-ref` - Human Interface Guidelines
- `swiftui-performance` - SwiftUI render optimization
- `ui-testing` - UI test patterns
- `swiftui-debugging` - Debug SwiftUI issues

### Concurrency (Swift 6)
- `swift-concurrency` - async/await, actors, @MainActor, Sendable
- Use for ANY actor isolation errors or concurrency issues

### Data & Persistence
- **Supabase**: Use `supabase-swift` SDK and GitHub MCP server for all backend data
- `swiftdata` - Local persistence with @Model, @Query, ModelContext
- For migrations: Prefer Supabase migrations over Axiom database skills
- **IMPORTANT**: See `.claude/rules/swiftdata-view-model.md` for iOS SwiftData patterns:
  - "Pass Objects, Not IDs" - prevents stale relationship arrays
  - Use `modelContext.safeDelete(flowId:)` for cascade deletes - prevents `_FullFutureBackingData` crash

### Debugging
- `memory-debugging` - Memory leaks, retain cycles
- `performance-profiling` - Instruments, profiling

### Runtime Debug Log
The app writes a debug log that Claude can read to understand app state:

```
Read "/Users/adam/Library/Containers/com.heyadam.composer/Data/Library/Application Support/Composer/Logs/debug.log"
```

**What's logged:**
- Flow state (nodes, edges, connections, values)
- Execution timing and results
- API requests/responses (keys redacted)
- Structure changes (node/edge add/delete)
- Errors with context

**When to check the debug log:**
- After implementing new features - verify they work at runtime
- When debugging execution issues - see API calls and responses
- When flow state seems incorrect - inspect actual data
- After user reports a bug - understand what happened

### Networking
- `networking` / `networking-diag` - URLSession, async networking
- `network-framework-ref` - Network.framework reference

### Project Health
- `/axiom:status` - Project health dashboard
- `/axiom:audit` - Smart audit selector

### Visual Verification (Required for UI Changes)

**After ANY UI implementation, you MUST verify visually:**

1. Build and run with `mcp__XcodeBuildMCP__build_run_sim` or `build_run_macos`
2. Use `mcp__XcodeBuildMCP__screenshot` to capture and verify the UI
3. Use `mcp__XcodeBuildMCP__describe_ui` to inspect element hierarchy and frames
4. If interactive testing needed, use XcodeBuildMCP gesture tools (`tap`, `swipe`, etc.)

**Do NOT consider UI work complete until visually verified.** Screenshots catch issues that builds miss (layout, styling, visual regressions).

| Tool | When to Use |
|------|-------------|
| `mcp__XcodeBuildMCP__screenshot` | Quick visual check of static UI |
| `mcp__XcodeBuildMCP__describe_ui` | Inspect element frames and hierarchy |
| `mcp__XcodeBuildMCP__tap/swipe/gesture` | Interactive flows, gestures, animations |

### UI Automation (XcodeBuildMCP)

XcodeBuildMCP provides comprehensive UI automation for the iOS Simulator:

| Tool | Description |
|------|-------------|
| `tap` | Tap at coordinates (x, y) or by accessibility `id`/`label` |
| `long_press` | Long press at coordinates for specified duration |
| `swipe` | Swipe from (x1, y1) to (x2, y2) |
| `gesture` | Preset gestures: `scroll-up`, `scroll-down`, `swipe-from-left-edge`, etc. |
| `type_text` | Type text into focused field |
| `key_press` | Press single key by keycode |
| `button` | Press hardware button: `home`, `lock`, `siri`, etc. |

**Workflow for interactive testing:**
1. `describe_ui` - Get element frames and accessibility IDs
2. `tap(id: "myButton")` or `tap(x: 200, y: 400)` - Interact with elements
3. `screenshot` - Verify result

**Important:** Always use `describe_ui` to get precise coordinates before using coordinate-based interactions. Don't guess from screenshots.

### Skill Trigger Examples

**Code Creation - invoke skill FIRST, then implement:**
```
"Add SwiftUI view"                   → axiom:swiftui-26-ref → write code
"Implement Liquid Glass toolbar"     → axiom:liquid-glass → write code
"Add async network call"             → axiom:networking → write code
"Store data with SwiftData"          → axiom:swiftdata → write code
"Add on-device AI feature"           → axiom:foundation-models → write code
```

**Testing - invoke skill FIRST, then write tests:**
```
"Add unit tests for X"               → axiom:testing → write tests → test_macos/test_sim
"Add UI tests for flow"              → axiom:ui-testing → write tests → test_macos/test_sim
```

**Debugging - invoke skill to diagnose:**
```
"Actor isolation errors"             → axiom:swift-concurrency
"App has memory leaks"               → axiom:memory-debugging
"Build mysteriously fails"           → /axiom:fix-build
```

## When to Verify with Context7

Use Context7 to spot-check Axiom's recommendations or when you need authoritative API references:

- **Supabase Swift SDK** - Backend integration patterns
- **Swift** - Language features beyond concurrency
- **SwiftUI** - iOS 26/macOS 26 view APIs
- **Foundation** - Networking, data, Observation framework

Context7 has up-to-date references for new iOS 26/macOS 26 APIs. If something from Axiom looks unfamiliar or outdated, verify with Context7 before implementing.

## Web App Foundation

This native app integrates with the Composer web app backend.

- **Web app location**: `~/dev/composer`
- **Live URL**: https://composer.design
- **Backend**: Next.js API routes, Supabase (PostgreSQL + Realtime)
- **Auth**: Supabase Auth (Google OAuth)

## Backend Context

Read `docs/NATIVE_APP_CONTEXT.md` for comprehensive backend documentation:

- API endpoints and request/response formats
- Data models (Flow, Node, Edge structures)
- Authentication and API key encryption
- Real-time collaboration via Supabase Realtime
- Share tokens and live collaboration URLs
- Rate limiting and error handling

This file is the authoritative reference for all backend integration work.

## Key Concepts

- **Flow**: Graph of connected nodes representing an AI workflow
- **Node**: Unit of work (input, processing, output)
- **Edge**: Connection between node ports
- **Share Token**: 12-char secret for accessing published flows
- **Live ID**: 4-digit human-readable code for share URLs
- **Owner-Funded Execution**: Collaborators use flow owner's encrypted API keys

## Native Implementation Notes

- Use `supabase-swift` for auth, database, and realtime subscriptions
- Parse NDJSON for streaming execution responses
- Use native WebRTC for realtime voice (get ephemeral token from API)
- Consider Core Data or SwiftData for offline flow caching
- Implement Universal Links for `composer.design/f/[liveId]/[token]`

## Canvas Implementation

The flow canvas is implemented with SwiftUI and supports:

### Architecture
- **FlowCanvasView**: Main container with ZStack layers (grid → edges → preview → nodes)
- **CanvasState**: `@Observable` state for transform, selection, and connection tracking
- **Port Position Registry**: Ports register their screen positions via `CanvasState.portPositions`
- **Named Coordinate Space**: All gestures and positions use `CanvasCoordinateSpace.name`

### Gestures
- **Pan**: DragGesture on canvas background
- **Zoom (iOS)**: MagnifyGesture (pinch) - uses `.simultaneousGesture` to avoid conflicts
- **Zoom (macOS)**: Option + scroll wheel via `ScrollWheelModifier` (NSViewRepresentable)
- **Node Drag**: DragGesture with transient position updates (commits to SwiftData on end)
- **Port Connection**: `.highPriorityGesture` on port HStack to win over node drag

### Key Files
- `Canvas/FlowCanvasView.swift` - Main canvas, coordinate space, macOS scroll handler
- `Canvas/CanvasState.swift` - Transform state, port registry, selection
- `Canvas/EdgeLayer.swift` - Bezier edge rendering using registered port positions
- `Canvas/ConnectionPreview.swift` - Dashed line during connection drag
- `Nodes/PortView.swift` - Port circles with position registration
- `Nodes/NodeContainerView.swift` - Node wrapper with `.scaleEffect(state.scale)`

### Known Patterns
- Nodes scale with canvas via `.scaleEffect(state.scale)` on node content
- Edge positions come from `state.portPositions["\(nodeId):\(portId)"]`
- Port positions registered via GeometryReader in named coordinate space
- iOS 26 Liquid Glass avoided on transformed views (causes `_UIGravityWellEffectAnchorView` errors)

### Gesture Priority (Critical)

Gestures must maintain this priority order - see `.claude/rules/gesture-tests.md`:

1. **Port connection** (highest) - `minimumDistance: 0`, 44pt hit target
2. **Node drag** - `minimumDistance: 8`, bails out if `activeConnection` set
3. **Canvas pan** (lowest) - bails out if `isDraggingNode` or `activeConnection`

**After modifying gesture code, run tests:**
```bash
mcp__XcodeBuildMCP__test_macos  # Runs HitTesterTests, CanvasStateTests, KeyboardDeletionTests
```

## Adding New Nodes

Use the **add-composer-node** skill when implementing new node types. The skill provides:
- 4-step workflow with exact file paths
- Copy-paste templates for simple and executable nodes
- iOS SwiftData patterns to avoid crashes

**Invoke the skill:**
```
Skill: add-composer-node
```

Or ask naturally: "Add a node for X", "Create a new node type", "Implement a custom node"

### Quick Reference

| Step | File | Action |
|------|------|--------|
| 1 | `composer/Models/NodeType.swift` | Add enum case |
| 2 | `composer/NodeSystem/PortID.swift` | Add port ID constants |
| 3 | `composer/NodeSystem/Nodes/<Category>/` | Create node file |
| 4 | `composer/NodeSystem/NodeRegistry.swift` | Register node |

### Node Architecture

Each node is a self-contained enum conforming to `NodeDefinition`:

| Component | Purpose |
|-----------|---------|
| `NodeDefinition` protocol | Identity, ports, view, execution |
| `NodeRegistry` | Type-erased storage for all definitions |
| `NodeType` enum | Persisted to SwiftData |
| `PortID` constants | Persisted in FlowEdge |

**Templates available in skill:**
- `examples/SimpleNode.swift` - Pass-through nodes (TextInput, PreviewOutput)
- `examples/ExecutableNode.swift` - Async nodes with status (TextGeneration)
