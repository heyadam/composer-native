# Preview Sidebar Implementation Plan

## Overview

Add a right-side preview sidebar to composer-native showing results from PreviewOutput nodes. This matches the web app's "Outputs" tab. Debug tab deferred to follow-up task.

**Key decisions:**
- Outputs tab only (Debug tab deferred - requires execution pipeline changes)
- Resizable sidebar with drag handle (width persisted to UserDefaults)
- Shows only PreviewOutput node results
- Keep existing DebugConsoleView (bottom) separate

---

## Phase 1: Data Models & State

### New File: `composer/PreviewSidebar/PreviewSidebarTypes.swift`

```swift
import Foundation

// PreviewEntry - for Outputs tab (PreviewOutput nodes only)
struct PreviewEntry: Identifiable, Sendable {
    let id: UUID
    let nodeId: UUID
    let nodeLabel: String
    var status: ExecutionStatus  // from ExecutionTypes.swift
    var timestamp: Date
    var stringOutput: String?
    var imageOutput: Data?
    var audioOutput: Data?
    var error: String?
}
```

> **Note**: `ExecutionStatus` is imported from `ExecutionTypes.swift` (idle, running, success, error)

### New File: `composer/PreviewSidebar/PreviewSidebarState.swift`

```swift
@MainActor @Observable
final class PreviewSidebarState {
    var isVisible: Bool = false
    var previewEntries: [PreviewEntry] = []

    // Resizable width (persisted via @AppStorage in view)
    var width: CGFloat = 340
    static let minWidth: CGFloat = 240
    static let maxWidth: CGFloat = 600

    func toggle() { isVisible.toggle() }
    func clearEntries() { previewEntries.removeAll() }

    func addOrUpdatePreviewEntry(_ entry: PreviewEntry) {
        if let idx = previewEntries.firstIndex(where: { $0.nodeId == entry.nodeId }) {
            previewEntries[idx] = entry
        } else {
            previewEntries.append(entry)
        }
    }
}
```

---

## Phase 2: Sidebar Views

### New File: `composer/PreviewSidebar/PreviewSidebarView.swift`

Main container with header, content, and resize handle.

```swift
struct PreviewSidebarView: View {
    @Bindable var state: PreviewSidebarState
    @AppStorage("previewSidebarWidth") private var storedWidth: Double = 340

    var body: some View {
        VStack(spacing: 0) {
            PreviewSidebarHeader(
                outputCount: state.previewEntries.count,
                onClose: { state.isVisible = false }
            )
            Divider()
            PreviewOutputsContent(entries: state.previewEntries)
        }
        .frame(width: state.width)
        .background(.regularMaterial)
        .overlay(alignment: .leading) { ResizeHandle(width: $state.width) }
        .onAppear { state.width = storedWidth }
        .onChange(of: state.width) { _, newValue in storedWidth = newValue }
    }
}
```

### New File: `composer/PreviewSidebar/PreviewSidebarHeader.swift`

Title with output count + close button (no tabs since Debug is deferred).

```swift
struct PreviewSidebarHeader: View {
    let outputCount: Int
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text("Outputs (\(outputCount))")
                .font(.headline)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
```

### New File: `composer/PreviewSidebar/PreviewOutputsContent.swift`

ScrollView with LazyVStack of PreviewEntryCard. Empty state uses ContentUnavailableView.

### New File: `composer/PreviewSidebar/PreviewEntryCard.swift`

Card with status indicator, node label, and typed content (text/image/audio).

### New File: `composer/PreviewSidebar/OutputRenderers.swift`

Imports `ExecutionStatus` from `ExecutionTypes.swift` for status handling.

- `StatusIndicator` - icon + color by ExecutionStatus (idle/running/success/error)
- `TextOutputContent` - scrollable monospace text with `.textSelection(.enabled)`
- `ImageOutputContent` - platform-specific image rendering (`#if os(macOS)` for NSImage vs UIImage)
- `AudioOutputContent` - play button + placeholder waveform (basic implementation)

### New File: `composer/PreviewSidebar/ResizeHandle.swift`

6px drag handle on left edge. Changes cursor on macOS hover (`NSCursor.resizeLeftRight`).

---

## Phase 3: Integration

### Modify: `composer/ContentView.swift`

1. Add state property:
   ```swift
   @State private var previewSidebarState = PreviewSidebarState()
   ```

2. Wrap NavigationSplitView in HStack with sidebar:
   ```swift
   HStack(spacing: 0) {
       NavigationSplitView { ... } detail: { ... }

       if previewSidebarState.isVisible {
           PreviewSidebarView(state: previewSidebarState)
               .transition(.move(edge: .trailing))
       }
   }
   .animation(.easeInOut(duration: 0.25), value: previewSidebarState.isVisible)
   ```

3. Pass state to FlowCanvasView:
   ```swift
   FlowCanvasView(flow: flow) { viewModel in
       canvasViewModel = viewModel
       viewModel.previewSidebarState = previewSidebarState
   }
   ```

4. Add toolbar toggle button:
   ```swift
   Button { previewSidebarState.toggle() } label: {
       Label("Preview", systemImage: "sidebar.trailing")
   }
   ```

### Modify: `composer/ViewModels/FlowCanvasViewModel.swift`

1. Add property:
   ```swift
   var previewSidebarState: PreviewSidebarState?
   ```

2. In `executeFlow()`, clear entries at start:
   ```swift
   previewSidebarState?.clearEntries()
   ```

3. After processing each PreviewOutput node, update sidebar using **inputs** (not outputs):

   > **CRITICAL**: PreviewOutput nodes are pass-through and return empty `NodeOutputs()`. The sidebar must read from the **inputs** gathered for the node, which contain upstream node values.

   ```swift
   // In executeFlow(), after gatherInputs(for: node):
   if node.nodeType == .previewOutput {
       let entry = PreviewEntry(
           id: UUID(),
           nodeId: node.id,
           nodeLabel: node.label,
           status: .success,
           timestamp: Date(),
           // Read from INPUTS (gathered from upstream nodes), not outputs
           stringOutput: inputs.string(for: PortID.previewInputString),
           imageOutput: inputs.imageData(for: PortID.previewInputImage),
           audioOutput: inputs.audioData(for: PortID.previewInputAudio)
       )
       previewSidebarState?.addOrUpdatePreviewEntry(entry)
   }
   ```

   The key insight: `gatherInputs(for:)` already fetches upstream output values and maps them to the node's input ports. Use `inputs` directly.

---

## File Structure

```
composer/PreviewSidebar/
├── PreviewSidebarTypes.swift      # PreviewEntry struct
├── PreviewSidebarState.swift      # @Observable state management
├── PreviewSidebarView.swift       # Main container
├── PreviewSidebarHeader.swift     # Title + close button
├── PreviewOutputsContent.swift    # Outputs list content
├── PreviewEntryCard.swift         # Individual output card
├── OutputRenderers.swift          # Text, Image, Audio renderers
└── ResizeHandle.swift             # Drag handle for resize
```

**7 new files** (Debug tab files deferred)

---

## Implementation Order

1. **PreviewSidebarTypes.swift** - Data model (no dependencies)
2. **PreviewSidebarState.swift** - State management
3. **OutputRenderers.swift** - Reusable content renderers (imports ExecutionTypes)
4. **PreviewEntryCard.swift** - Uses OutputRenderers
5. **PreviewOutputsContent.swift** - Uses PreviewEntryCard
6. **PreviewSidebarHeader.swift** - Title + close button
7. **ResizeHandle.swift** - Drag resize
8. **PreviewSidebarView.swift** - Assembles all components
9. **ContentView.swift** - Layout integration + toolbar
10. **FlowCanvasViewModel.swift** - Execution integration (use inputs, not outputs)

---

## Critical Files

| File | Changes |
|------|---------|
| `composer/ContentView.swift` | Add sidebar state, HStack layout, toolbar button |
| `composer/ViewModels/FlowCanvasViewModel.swift` | Add sidebar state, populate from **inputs** in executeFlow() |
| `composer/NodeSystem/ExecutionTypes.swift` | Reuse ExecutionStatus, NodeInputs (no changes needed) |
| `composer/NodeSystem/PortID.swift` | Use existing port ID constants |

---

## Visual Verification

After implementation, verify with:
1. `mcp__XcodeBuildMCP__build_run_sim` or `build_run_macos`
2. `mcp__XcodeBuildMCP__screenshot` - Check sidebar appears/hides correctly
3. Run a flow with PreviewOutput node connected to TextGeneration → verify text output appears
4. Run a flow with ImageGeneration → PreviewOutput → verify image appears
5. Test resize handle drag on macOS

---

## Follow-up: Debug Tab

Deferred to a follow-up task. Will require:
1. Modifying execution pipeline to capture API request/response details
2. Adding `DebugEntry` struct with provider, model, prompt, response fields
3. Adding `PreviewDebugContent.swift` with collapsible sections
4. Updating header to support tab switching
