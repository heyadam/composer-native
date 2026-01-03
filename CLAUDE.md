# Composer Native

Universal macOS/iOS app for Composer - a visual AI workflow builder.

## Deployment Targets
- iOS 26+
- macOS 26+

## Building: Use Xcode Tools Plugin

Build and test the project using these commands:

```
/build          # Build for macOS (default)
/build ios      # Build for iOS Simulator
/build mac      # Build for macOS
/test           # Run all tests
/test unit      # Run unit tests only
/test ui        # Run UI tests only
```

On build failure:
- **Auto-fix**: Missing imports, `await` keywords, simple typos
- **Ask first**: Architectural changes, ambiguous fixes

## Development: Use Axiom Plugin

Use Axiom skills for iOS/Swift development. Invoke the relevant skill BEFORE implementing features.

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
- `xcode-debugging` - Xcode build failures, stale builds
- `memory-debugging` - Memory leaks, retain cycles
- `build-debugging` - Build system issues
- `performance-profiling` - Instruments, profiling

### Networking
- `networking` / `networking-diag` - URLSession, async networking
- `network-framework-ref` - Network.framework reference

### Project Health
- `/axiom:status` - Project health dashboard
- `/axiom:audit` - Smart audit selector

### Trigger Examples
```
"BUILD FAILED with stale builds"     → xcode-debugging
"Actor isolation errors in Swift 6"  → swift-concurrency
"Add a column to database safely"    → database-migration
"App has memory leaks"               → memory-debugging
"Implement Liquid Glass toolbar"     → liquid-glass
```

## Documentation: Use Context7

For API documentation not covered by Axiom skills, consult Context7:

- **Supabase Swift SDK** - Backend integration (primary data source)
- **Swift** - Language features beyond concurrency
- **SwiftUI** - New iOS 26/macOS 26 view APIs
- **Foundation** - Networking, data, Observation framework

**Important**: If Axiom skills show API patterns that seem outdated or inconsistent, double-check with Context7 for the latest documentation. iOS 26/macOS 26 APIs are new and Context7 has authoritative, up-to-date references.

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
