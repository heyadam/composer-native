# Gesture and Hit Testing Rules

## When to Run Tests

After modifying any of the following files, run the gesture tests to ensure hit testing and gesture priority still work correctly:

- `composer/Nodes/PortView.swift` - Port connection gestures
- `composer/Nodes/NodeContainerView.swift` - Node drag/selection gestures
- `composer/Canvas/FlowCanvasView.swift` - Canvas pan/zoom gestures
- `composer/Canvas/CanvasState.swift` - Port registry, hit detection, state
- `composer/Gestures/HitTester.swift` - Hit testing logic

## Running Tests

```bash
# Run all gesture-related unit tests
xcodebuild test -scheme composer -destination 'platform=macOS' -only-testing:composerTests/HitTesterTests -only-testing:composerTests/CanvasStateTests

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

## Gesture Priority Order

1. **Port connection drag** (highest) - `PortView.highPriorityGesture`
2. **Node drag** - `NodeContainerView.gesture`
3. **Canvas pan** (lowest) - `FlowCanvasView.simultaneousGesture`

When modifying gestures, maintain this priority order. The port uses a 44x44pt hit target with `minimumDistance: 0` to claim touches before the node drag (which uses `minimumDistance: 8`).
