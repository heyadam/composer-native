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

**Default to Axiom** for all iOS/Swift development. Invoke the relevant skill BEFORE implementing features. Occasionally verify with Context7 when APIs seem unfamiliar or you want to double-check syntax.

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

### Visual Verification
After implementing UI changes, use Axiom to verify the code works correctly:
- `/axiom:screenshot` - Capture screenshot from iOS Simulator
- `/axiom:test-simulator` - Launch simulator testing agent for interactive verification

**Default behavior**: Always visually verify UI code changes before considering them complete.

### Trigger Examples
```
"Actor isolation errors in Swift 6"  → swift-concurrency
"App has memory leaks"               → memory-debugging
"Implement Liquid Glass toolbar"     → liquid-glass
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
