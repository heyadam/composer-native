# Composer Native

Universal macOS/iOS app for Composer - a visual AI workflow builder.

## Deployment Targets
- iOS 26+
- macOS 26+

## Documentation: Use Context7

iOS 26 and macOS 26 documentation is very recent. Always consult Context7 for up-to-date docs when working with:

- **Swift** - Language features, concurrency (async/await, actors)
- **SwiftUI** - Views, modifiers, new iOS 26/macOS 26 APIs
- **Foundation** - Networking, data, Observation framework
- **Combine** - Reactive patterns (where still needed)
- **SwiftData** - Persistence (if used)
- **Supabase Swift SDK** - Backend integration

Query Context7 proactively before implementing platform APIs, especially for new iOS 26/macOS 26 features.

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
