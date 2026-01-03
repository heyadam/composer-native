# Code Audit Report: SwiftUI Canvas Implementation

**Date:** 2026-01-03
**Spec Reference:** `docs/nodes.md`
**Overall Assessment:** Good (4/5)

---

## Summary

The implementation closely follows the spec and uses good SwiftUI patterns. The architecture is clean with proper MVVM separation, SwiftData relationships work correctly, and gesture handling follows the priority system outlined in the spec. A few issues need attention, primarily around edge selection and code duplication.

---

## Strengths

### 1. Clean MVVM Architecture
Proper separation between `FlowCanvasViewModel`, `NodeViewModel`, `ConnectionViewModel` and views. State management follows the spec's recommendations.

### 2. SwiftData Relationships
Bidirectional relationships with cascade delete rules implemented correctly:
- `FlowNode.outgoingEdges` / `FlowEdge.sourceNode`
- `FlowNode.incomingEdges` / `FlowEdge.targetNode`
- `Flow.nodes` / `FlowNode.flow`

### 3. Gesture Priority Handling
Follows spec exactly:
1. TextEditor focus → disables canvas gestures via `isEditingNode`
2. Port connection → `.highPriorityGesture` wins over node drag
3. Node drag → `.gesture` with state machine
4. Canvas pan/zoom → `.simultaneousGesture`, disabled during editing

### 4. Port Position Registry
Screen positions tracked via `CanvasState.portPositions` using named coordinate space. EdgeLayer reads from registry for accurate bezier endpoints.

### 5. Transient Drag Pattern
Node drag updates are in-memory only (`draggedNodePositions`), commits to SwiftData on drag end. Prevents excessive disk writes during interaction.

### 6. Liquid Glass Workaround
Correctly avoids `.glassEffect()` on transformed views per spec note about `_UIGravityWellEffectAnchorView` errors. Uses solid semi-transparent background instead.

---

## Issues Found

### 1. DRY Violation: Duplicate Port Drag Handlers

**Severity:** Medium
**Location:**
- `composer/Nodes/TextInputNodeView.swift:57-121`
- `composer/Nodes/PreviewOutputNodeView.swift:113-177`

**Description:**
Both node views contain identical port drag handling code (`handlePortDragStart`, `handlePortDragUpdate`, `handlePortDragEnd`, `findPortType`).

**Impact:** Maintenance burden, bug duplication risk

**Recommendation:** Extract to a shared protocol extension or helper struct:
```swift
protocol PortDragHandling {
    var node: FlowNode { get }
    var state: CanvasState { get }
    var connectionViewModel: ConnectionViewModel? { get }
}

extension PortDragHandling {
    func handlePortDragStart(_ port: PortDefinition, _ isOutput: Bool, _ position: CGPoint) { ... }
    // etc.
}
```

---

### 2. Edge Hit Testing Not Implemented

**Severity:** Medium
**Location:** `composer/Canvas/EdgeLayer.swift:42`

**Description:**
EdgeLayer has `allowsHitTesting(false)`. The `distanceToEdge` helper exists (line 100-114) but is never called. Users cannot tap to select edges.

**Spec says:** "Click/tap on edge (8pt hit tolerance from bezier curve)"

**Impact:** Cannot select or delete edges via tap/click

**Recommendation:** Add hit testing layer or use `onTapGesture` with manual hit detection:
```swift
.contentShape(Rectangle())
.onTapGesture { location in
    for edge in edges {
        if EdgeLayer.distanceToEdge(from: location, ...) < 8 {
            state.selectEdge(edge.id)
            return
        }
    }
}
```

---

### 3. Missing iOS Multi-Select

**Severity:** Low
**Location:** `composer/Nodes/NodeContainerView.swift:152-165`

**Description:**
Only handles Cmd+click on macOS. iOS falls through to single select only.

```swift
#else
state.selectNode(node.id)  // No long-press option
#endif
```

**Spec says:** "Cmd+Tap (macOS) / long-press (iOS) for multi-select"

**Recommendation:** Add long-press gesture for iOS:
```swift
#if os(iOS)
.simultaneousGesture(
    LongPressGesture(minimumDuration: 0.5)
        .onEnded { _ in
            state.toggleNodeSelection(node.id)
        }
)
#endif
```

---

### 4. Silent Error Swallowing

**Severity:** Low
**Location:**
- `composer/Nodes/TextInputNodeView.swift:98`
- `composer/Nodes/PreviewOutputNodeView.swift:153`

**Description:**
Connection errors are silently ignored with `try?`:
```swift
try? connectionViewModel?.completeConnection(to: targetPoint)
```

**Impact:** User gets no feedback when connection fails (incompatible types, circular connection, etc.)

**Recommendation:** Show error feedback:
```swift
do {
    try connectionViewModel?.completeConnection(to: targetPoint)
} catch {
    // Show shake animation or toast per spec
    withAnimation(.default.repeatCount(3)) {
        showConnectionError = true
    }
}
```

---

### 5. Inefficient `findPortType` Lookup

**Severity:** Low
**Location:**
- `composer/Nodes/TextInputNodeView.swift:107-121`
- `composer/Nodes/PreviewOutputNodeView.swift:163-177`

**Description:**
Iterates through all nodes and their ports to find a port's data type. This is O(n*m) where n=nodes, m=ports per node.

**Recommendation:** The port registry could store `dataType` (it already does in `registerPort`), but retrieval isn't exposed. Add a lookup method to `CanvasState`:
```swift
func portDataType(nodeId: UUID, portId: String) -> PortDataType? {
    // Could store in separate dictionary during registration
}
```

---

### 6. Unused Gesture Files

**Severity:** Low
**Location:** `composer/Gestures/` directory

**Description:**
The folder contains 7 Swift files, but gesture logic is inlined in `FlowCanvasView` and `NodeContainerView`. These files may be empty stubs or dead code.

**Files:**
- `HitTester.swift`
- `CanvasPanGesture.swift`
- `CanvasZoomGesture.swift`
- `NodeDragGesture.swift`
- `ConnectionGesture.swift`
- `SelectionGesture.swift`
- `TextEditingCoordinator.swift`

**Recommendation:** Either:
1. Move inline gesture logic to these files for better organization
2. Delete unused files to reduce confusion

---

### 7. PreviewOutput Shows Only First Connection

**Severity:** Low
**Location:** `composer/Nodes/PreviewOutputNodeView.swift:95`

**Description:**
Only checks first incoming edge, ignoring the other 2 input ports (Image, Audio):
```swift
guard let incomingEdge = node.incomingEdges.first
```

**Spec defines 3 input ports:** Text, Image, Audio

**Recommendation:** Check all incoming edges and display appropriate content for each connected type.

---

### 8. No Exit from Text Editing via Canvas Tap

**Severity:** Low
**Location:** `composer/Canvas/FlowCanvasView.swift:120-125`

**Description:**
Tapping the canvas background clears selection but doesn't unfocus the TextEditor. User must tap elsewhere or press Escape.

**Recommendation:** Resign first responder on canvas tap:
```swift
private var canvasTapGesture: some Gesture {
    TapGesture()
        .onEnded {
            canvasState.clearSelection()
            #if os(iOS)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #else
            NSApp.keyWindow?.makeFirstResponder(nil)
            #endif
        }
}
```

---

## Spec Compliance Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| TextInput + PreviewOutput nodes | ✅ | Working |
| SwiftData persistence | ✅ | Relationships correct |
| Pan gesture | ✅ | Working |
| Zoom (iOS pinch) | ✅ | MagnifyGesture |
| Zoom (macOS Option+scroll) | ✅ | ScrollWheelModifier |
| Port position registry | ✅ | Named coordinate space |
| Bezier edge rendering | ✅ | Canvas with drawingGroup |
| Connection drag preview | ✅ | Dashed line working |
| Node drag (transient) | ✅ | No SwiftData writes during drag |
| Single-select nodes | ✅ | Working |
| Multi-select nodes (macOS) | ✅ | Cmd+click |
| Multi-select nodes (iOS) | ❌ | Missing long-press |
| Edge selection via tap | ❌ | Hit testing disabled |
| Edge deletion | ⚠️ | Delete key works, tap select missing |
| Delete key (macOS) | ✅ | .onDeleteCommand |
| Context menu delete | ✅ | Working |
| VoiceOver labels | ✅ | Basic labels present |
| Rotor navigation | ⚠️ | Files exist, integration unclear |
| Validation badges | ❌ | Not implemented |
| Error feedback (shake/toast) | ❌ | Errors silently swallowed |

---

## Recommended Priority

1. **High:** Fix edge selection (enables edge deletion workflow)
2. **Medium:** Extract duplicate port drag handlers (reduces bugs)
3. **Medium:** Add error feedback for failed connections
4. **Low:** iOS multi-select, cleanup unused files

---

## Files Reviewed

| File | Lines | Notes |
|------|-------|-------|
| `Canvas/FlowCanvasView.swift` | 204 | Main container, gestures |
| `Canvas/CanvasState.swift` | 171 | Observable state |
| `Canvas/EdgeLayer.swift` | 141 | Bezier rendering |
| `Nodes/NodeContainerView.swift` | 183 | Drag, selection wrapper |
| `Nodes/NodeFrame.swift` | 200 | Liquid Glass chrome |
| `Nodes/PortView.swift` | 150 | Port circles, gestures |
| `Nodes/TextInputNodeView.swift` | 136 | Text input node |
| `Nodes/PreviewOutputNodeView.swift` | 210 | Preview output node |
| `ViewModels/FlowCanvasViewModel.swift` | 217 | Canvas orchestration |
| `ViewModels/NodeViewModel.swift` | 75 | Node transient state |
| `ViewModels/ConnectionViewModel.swift` | 120 | Connection management |
| `Models/FlowNode.swift` | 79 | SwiftData model |
