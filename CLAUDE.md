# Composer Native

Universal macOS/iOS app for Composer - a visual AI workflow builder.

## Deployment Targets
- iOS 26+
- macOS 26+

## Building: Use Xcode Tools Plugin

Build and test the project:

```
/build          # Build for macOS (default)
/build ios      # Build for iOS Simulator
/test           # Run all tests
/test unit      # Run unit tests only
/test ui        # Run UI tests only
```

On build failure:
- **Auto-fix**: Missing imports, `await` keywords, simple typos
- **Ask first**: Architectural changes, ambiguous fixes
- **Mysterious failures**: Use `/axiom:fix-build` (see below)

## Build & Debug Troubleshooting

| Situation | Use |
|-----------|-----|
| Run a build | `/build` or `/build ios` |
| Run tests | `/test` |
| Build fails with code errors | `/build` auto-fixes simple issues |
| Mysterious failures (no clear error, stale code, "No such module") | `/axiom:fix-build` |
| Builds are slow | `/axiom:optimize-build` |
| Runtime issues (execution, API, state) | Read the debug log (see Debugging section) |
| Verify new feature works | Build, run app, check debug log |

**`/build`** executes `xcodebuild` and parses errors. **`/axiom:fix-build`** diagnoses environment issues (zombie processes, stale Derived Data, stuck simulators) that cause mysterious failures.

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
3. Use `/test` to run the tests after implementation

**Example workflow:**
```
User: "Add a new button with Liquid Glass styling"
→ Invoke axiom:liquid-glass skill
→ Read current Liquid Glass API patterns
→ Implement the button using skill guidance
→ Build with /build
→ Verify visually with /axiom:screenshot
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
- **IMPORTANT**: See `.claude/rules/swiftdata-view-model.md` for the "Pass Objects, Not IDs" pattern - prevents stale relationship arrays on iOS

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

1. Build the app with `/build`
2. Launch in simulator (user will do this)
3. Use `/axiom:screenshot` to capture and verify the UI
4. If interactive testing needed, use `/axiom:test-simulator`

**Do NOT consider UI work complete until visually verified.** Screenshots catch issues that builds miss (layout, styling, visual regressions).

| Tool | When to Use |
|------|-------------|
| `/axiom:screenshot` | Quick visual check of static UI |
| `/axiom:test-simulator` | Interactive flows, gestures, animations |

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
"Add unit tests for X"               → axiom:testing → write tests → /test
"Add UI tests for flow"              → axiom:ui-testing → write tests → /test
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
/test unit  # Runs HitTesterTests and CanvasStateTests
```
