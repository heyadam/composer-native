# Gesture, Input, and Hit Testing Rules

## When to Run Tests

After modifying any of the following files, run the gesture tests to ensure hit testing, gesture priority, and keyboard input still work correctly:

- `composer/Nodes/PortView.swift` - Port connection gestures
- `composer/Nodes/NodeContainerView.swift` - Node drag/selection gestures
- `composer/Canvas/FlowCanvasView.swift` - Canvas pan/zoom gestures, keyboard deletion (macOS)
- `composer/Canvas/CanvasState.swift` - Port registry, hit detection, selection state
- `composer/Gestures/HitTester.swift` - Hit testing logic

## Running Tests

```bash
# Run all gesture and input-related unit tests
xcodebuild test -scheme composer -destination 'platform=macOS' -only-testing:composerTests/HitTesterTests -only-testing:composerTests/CanvasStateTests -only-testing:composerTests/KeyboardDeletionTests

# Quick test run (just gesture tests)
/test unit
```

## Test Coverage

The gesture tests verify:

1. **Port Priority** - Ports always win over nodes and canvas for hit testing
2. **Hit Radius** - 22pt radius for port detection, 30pt for gesture bailout
3. **State Blocking** - `activeConnection` blocks canvas pan and node drag
4. **Coordinate Transforms** - Screen-to-world and world-to-screen conversions
5. **Node Selection** - Selection state management
6. **Keyboard Deletion** - Delete key deletes selected nodes/edges (macOS)

## Gesture Priority Order

1. **Port connection drag** (highest) - `PortView.highPriorityGesture`
2. **Node drag** - `NodeContainerView.gesture`
3. **Canvas pan** (lowest) - `FlowCanvasView.simultaneousGesture`

When modifying gestures, maintain this priority order. The port uses a 44x44pt hit target with `minimumDistance: 0` to claim touches before the node drag (which uses `minimumDistance: 8`).

## Keyboard Input (macOS)

Keyboard deletion is handled via `NSEvent.addLocalMonitorForEvents` in the `CanvasInputView` class within `FlowCanvasView.swift`. This approach:

- Catches Delete/Backspace keys at the application level
- Skips deletion when a text field is focused (allows typing)
- Uses guard conditions: `!canvasState.isEditingNode && canvasState.hasSelection`

**Important**: Do NOT use SwiftUI's `.focusable()` modifier on the canvas - it breaks pinch-to-zoom gestures on macOS. The NSEvent monitor approach avoids this conflict.
