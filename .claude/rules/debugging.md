# Debugging Rules

## Debug Log Location

The app writes runtime debug information to:
```
/Users/adam/Library/Containers/com.heyadam.composer/Data/Library/Application Support/Composer/Logs/debug.log
```

Read this file to understand what's happening in the running app.

## When to Check the Debug Log

**Always check the debug log after:**
1. Implementing new node types or execution logic
2. Modifying API calls or network code
3. Changing flow state management
4. Adding/removing nodes or edges programmatically
5. User reports unexpected behavior

**The log contains:**
- `[FLOW_STATE]` - Complete snapshot of nodes, edges, and their data
- `[EXECUTION]` - Flow execution timing and per-node results
- `[API]` - HTTP requests (with keys redacted) and responses
- `[EVENT]` - Structure changes (node/edge add/delete)
- `[ERROR]` - Errors with context

## Debugging Workflow

1. **Build the app**: `/build`
2. **Launch and reproduce the issue**: Open the app, trigger the behavior
3. **Read the debug log**:
   ```
   Read "/Users/adam/Library/Containers/com.heyadam.composer/Data/Library/Application Support/Composer/Logs/debug.log"
   ```
4. **Analyze the output**: Look for errors, unexpected state, or missing data
5. **Fix and verify**: Make changes, rebuild, check log again

## Adding Debug Logging

When implementing new features, add logging calls:

```swift
// Log events
DebugLogger.shared.logEvent("Description of what happened")

// Log errors
DebugLogger.shared.logError(error, context: "What was being attempted")

// Log flow state (done automatically on changes)
DebugLogger.shared.logFlowState(flow)
```

## Key Files

- `Debug/DebugLogger.swift` - The logging singleton
- Logs are written to the app's sandbox container (not ~/Library/Logs)
- Max file size: 100KB (auto-truncates older entries)
