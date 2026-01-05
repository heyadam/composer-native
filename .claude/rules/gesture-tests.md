# Gesture, Input, and Hit Testing Rules

## When to Run Tests

After modifying any of the following files, run the gesture tests to ensure hit testing, gesture priority, and keyboard input still work correctly:

- `composer/Nodes/PortView.swift` - Port connection gestures
- `composer/Nodes/NodeContainerView.swift` - Node drag/selection gestures
- `composer/Canvas/FlowCanvasView.swift` - Canvas pan/zoom gestures, keyboard deletion (macOS)
- `composer/Canvas/CanvasState.swift` - Port registry, hit detection, selection state
- `composer/Canvas/EdgeLayer.swift` - Edge hit testing and selection
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
6. **Edge Selection** - Edge selection state, mutual exclusivity with nodes
7. **Keyboard Deletion** - Delete key deletes selected nodes/edges (macOS + iOS)

## Gesture Priority Order

### Drag Gestures (controlled by gesture modifiers)

1. **Port connection drag** (highest) - `PortView.highPriorityGesture`
2. **Node drag** - `NodeContainerView.gesture`
3. **Canvas pan** (lowest) - `FlowCanvasView.simultaneousGesture`

The port uses a 44x44pt hit target with `minimumDistance: 0` to claim touches before the node drag (which uses `minimumDistance: 8`).

### Tap Gestures (handled by canvas tap gesture)

The canvas uses a `SpatialTapGesture` with `.simultaneousGesture` that performs hit testing and routes taps:

1. **Node tap** - Detected via `hitTestNode()`, but selection handled by `NodeContainerView`
2. **Edge tap** - Detected via `hitTestEdge()`, selected directly by canvas tap gesture
3. **Empty canvas tap** - Clears selection

**Critical**: Edge selection is handled by the canvas tap gesture, NOT by `EdgeHitTestingLayer`. The canvas `.simultaneousGesture` consumes taps before child views can receive them. Always use manual hit testing in the canvas gesture for reliable tap handling.

### Touch Target Sizes

- **Edge hit radius**: 22pt (44pt diameter, Apple HIG minimum for touch)
- **Port hit radius**: 22pt for detection, 30pt for gesture bailout
- **Context menu targets**: 44pt, scaled inversely with zoom

## Known Patterns & Gotchas

### `.simultaneousGesture` Consumes Taps

When a parent view uses `.simultaneousGesture` with a tap gesture, child views' tap gestures may not receive the tap. The parent gesture runs first and can "consume" the event.

**Solution**: Perform hit testing in the parent gesture and handle selection directly, rather than relying on child view tap gestures.

```swift
// ✅ Correct: Parent gesture does hit testing and selection
.simultaneousGesture(
    SpatialTapGesture()
        .onEnded { value in
            if let edgeId = hitTestEdge(at: value.location) {
                state.selectEdge(edgeId)  // Select directly
            }
        }
)

// ❌ Wrong: Relying on child view's tap gesture
// EdgeHitTestingLayer's .onTapGesture won't receive taps
```

### ZStack Order for Drags vs Taps

- **Drag gestures**: Priority controlled by gesture modifiers (`.highPriorityGesture`, `.gesture`, `.simultaneousGesture`)
- **Tap gestures**: When using `.simultaneousGesture` on parent, use manual hit testing instead of relying on ZStack order

## Keyboard Input

### macOS

Keyboard deletion is handled via `NSEvent.addLocalMonitorForEvents` in the `CanvasInputView` class within `FlowCanvasView.swift`. This approach:

- Catches Delete/Backspace keys at the application level
- Skips deletion when a text field is focused (allows typing)
- Uses guard conditions: `!canvasState.isEditingNode && canvasState.hasSelection`

**Important**: Do NOT use SwiftUI's `.focusable()` modifier on the canvas - it breaks pinch-to-zoom gestures on macOS. The NSEvent monitor approach avoids this conflict.

### iOS

Keyboard deletion is handled via `UIKeyCommand` in `KeyboardDeleteHandler` within `FlowCanvasView.swift`:

- Responds to Delete and Backspace key commands (hardware keyboard)
- Uses a timer to periodically reclaim first responder (except when text fields are active)
- Same guard conditions as macOS: `!canvasState.isEditingNode && canvasState.hasSelection`
