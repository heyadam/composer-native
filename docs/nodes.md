# SwiftUI Canvas View Implementation Plan

## Overview

Implement a native SwiftUI canvas for visual node-graph workflows. The canvas supports adding nodes, connecting nodes via ports, and pan/zoom navigation. This follows the Composer web app's paradigms using pure SwiftUI with iOS 26+ Liquid Glass design.

## Scope

- **Nodes**: TextInput + PreviewOutput (minimal viable set)
- **Persistence**: SwiftData with bidirectional relationships
- **Collaboration**: Deferred (local-only first)
- **Platforms**: iOS 26+ / macOS 26+
- **Design**: Liquid Glass (WWDC 2025)

---

## Architecture

```
composer/
├── Models/
│   ├── Flow.swift              # SwiftData @Model
│   ├── FlowNode.swift          # SwiftData @Model (inverse relationship)
│   ├── FlowEdge.swift          # SwiftData @Model (node relationships)
│   ├── NodeType.swift          # Enum for node types
│   ├── PortDefinition.swift    # Port types and colors
│   └── NodePortSchemas.swift   # Port definitions per type
├── ViewModels/
│   ├── FlowCanvasViewModel.swift   # Orchestrates canvas operations
│   ├── NodeViewModel.swift         # Wraps FlowNode with transient state
│   └── ConnectionViewModel.swift   # Manages connection creation
├── Canvas/
│   ├── FlowCanvasView.swift    # Main container
│   ├── CanvasState.swift       # @MainActor @Observable state
│   ├── CoordinateTransform.swift
│   ├── EdgeLayer.swift         # Bezier edge rendering
│   ├── GridBackground.swift    # Dot grid
│   └── ConnectionPreview.swift # Drag-in-progress line
├── Nodes/
│   ├── NodeContainerView.swift # Drag + selection wrapper
│   ├── NodeFrame.swift         # Liquid Glass chrome
│   ├── PortView.swift          # Port circles + gestures
│   ├── TextInputNodeView.swift
│   └── PreviewOutputNodeView.swift
├── Gestures/
│   ├── HitTester.swift             # Protocol-based hit testing
│   ├── CanvasPanGesture.swift      # Pan viewport
│   ├── CanvasZoomGesture.swift     # Zoom with anchor
│   ├── NodeDragGesture.swift       # Move nodes (transient state)
│   ├── ConnectionGesture.swift     # Create edges
│   ├── SelectionGesture.swift      # Multi-select
│   └── TextEditingCoordinator.swift # Focus state management
└── Accessibility/
    ├── NodeAccessibility.swift     # VoiceOver support
    └── CanvasAccessibility.swift   # Rotor navigation
```

---

## Implementation Steps

### Phase 1: Data Models

**Files to create:**

1. `composer/Models/NodeType.swift`
   - Enum with `textInput`, `previewOutput` cases
   - Extensible for future node types
   - Codable for SwiftData storage

2. `composer/Models/PortDefinition.swift`
   - `PortDataType` enum: `.string`, `.image`, `.audio`, etc.
   - Color mapping matching web app CSS variables
   - `PortDefinition` struct with id, label, dataType, isRequired
   - Environment entry for theming: `@Entry var portColors: PortColorScheme`

3. `composer/Models/Flow.swift`
   ```swift
   @Model
   final class Flow {
       var id: UUID
       var name: String
       var flowDescription: String  // 'description' is reserved
       var createdAt: Date
       var updatedAt: Date

       @Relationship(deleteRule: .cascade, inverse: \FlowNode.flow)
       var nodes: [FlowNode] = []

       @Relationship(deleteRule: .cascade, inverse: \FlowEdge.flow)
       var edges: [FlowEdge] = []
   }
   ```

4. `composer/Models/FlowNode.swift`
   ```swift
   @Model
   final class FlowNode {
       var id: UUID
       var nodeType: NodeType
       var positionX: Double
       var positionY: Double
       var label: String
       var dataJSON: Data?

       // Bidirectional relationship
       var flow: Flow?

       // Relationships for edges (not IDs)
       @Relationship(deleteRule: .cascade, inverse: \FlowEdge.sourceNode)
       var outgoingEdges: [FlowEdge] = []

       @Relationship(deleteRule: .cascade, inverse: \FlowEdge.targetNode)
       var incomingEdges: [FlowEdge] = []

       var position: CGPoint {
           get { CGPoint(x: positionX, y: positionY) }
           set { positionX = newValue.x; positionY = newValue.y }
       }
   }
   ```

   **Note on width/height**: Not persisted. Node size is measured dynamically via
   `GeometryReader` or `onGeometryChange()` and cached transiently in `NodeViewModel.measuredSize`.
   This avoids stale dimensions when content changes (e.g., text wrapping).

5. `composer/Models/FlowEdge.swift`
   ```swift
   @Model
   final class FlowEdge {
       var id: UUID
       var sourceHandle: String  // Port identifier
       var targetHandle: String  // Port identifier
       var dataType: PortDataType

       // Bidirectional relationship to Flow
       var flow: Flow?

       // Actual relationships (not string IDs)
       var sourceNode: FlowNode?
       var targetNode: FlowNode?
   }
   ```

6. `composer/Models/NodePortSchemas.swift`
   ```swift
   /// Stable port IDs - these must never change to preserve edge references
   enum PortID {
       // TextInput ports
       static let textInputOutput = "text-input.output"

       // PreviewOutput ports
       static let previewInputString = "preview.input.string"
       static let previewInputImage = "preview.input.image"
       static let previewInputAudio = "preview.input.audio"
   }

   enum NodePortSchemas {
       static func inputPorts(for type: NodeType) -> [PortDefinition] {
           switch type {
           case .textInput: return []
           case .previewOutput: return [
               PortDefinition(id: PortID.previewInputString, label: "Text", dataType: .string, isRequired: false),
               PortDefinition(id: PortID.previewInputImage, label: "Image", dataType: .image, isRequired: false),
               PortDefinition(id: PortID.previewInputAudio, label: "Audio", dataType: .audio, isRequired: false),
           ]
           }
       }

       static func outputPorts(for type: NodeType) -> [PortDefinition] {
           switch type {
           case .textInput: return [
               PortDefinition(id: PortID.textInputOutput, label: "Output", dataType: .string, isRequired: true)
           ]
           case .previewOutput: return []
           }
       }
   }
   ```
   - Port IDs are stable string constants (never reorder/rename)
   - Survives schema versioning - edges reference IDs, not indices

### Phase 2: ViewModels

**Files to create:**

1. `composer/ViewModels/FlowCanvasViewModel.swift`
   ```swift
   @MainActor @Observable
   final class FlowCanvasViewModel {
       private let modelContext: ModelContext
       private(set) var flow: Flow

       // Transient state (not persisted during drag)
       var draggedNodePositions: [UUID: CGPoint] = [:]
       var isDragging: Bool { !draggedNodePositions.isEmpty }

       func beginNodeDrag(_ nodeId: UUID, at position: CGPoint)
       func updateNodeDrag(_ nodeId: UUID, to position: CGPoint)
       func endNodeDrag(_ nodeId: UUID)  // Commits to SwiftData

       func addNode(_ type: NodeType, at position: CGPoint)
       func deleteNodes(_ ids: Set<UUID>)
       func createEdge(from: ConnectionPoint, to: ConnectionPoint) throws

       // Undo support via SwiftData
       var undoManager: UndoManager? { modelContext.undoManager }
   }
   ```

2. `composer/ViewModels/NodeViewModel.swift`
   ```swift
   @MainActor @Observable
   final class NodeViewModel {
       let node: FlowNode
       private let canvasViewModel: FlowCanvasViewModel

       // Transient position during drag (avoids SwiftData writes per frame)
       var displayPosition: CGPoint {
           canvasViewModel.draggedNodePositions[node.id] ?? node.position
       }

       // Measured size (not persisted, updated via onGeometryChange)
       var measuredSize: CGSize = CGSize(width: 200, height: 100)

       var isSelected: Bool = false
       var isEditing: Bool = false
   }
   ```

3. `composer/ViewModels/ConnectionViewModel.swift`
   - Manages connection creation state
   - Validates port compatibility
   - Provides compatible port highlighting

### Phase 3: Canvas Foundation

**Files to create:**

1. `composer/Canvas/CanvasState.swift`
   ```swift
   @MainActor @Observable
   final class CanvasState {
       // Transform constraints
       static let minScale: CGFloat = 0.25
       static let maxScale: CGFloat = 2.0

       // Transform
       var offset: CGSize = .zero
       private(set) var scale: CGFloat = 1.0

       // Selection
       var selectedNodeIds: Set<UUID> = []
       var selectedEdgeIds: Set<UUID> = []

       // Connection in progress
       var activeConnection: ConnectionPoint?
       var connectionEndPosition: CGPoint?

       // Editing state (disables canvas gestures)
       var isEditingNode: Bool = false

       // Canvas size (set via preference key, not in body)
       private(set) var canvasSize: CGSize = .zero

       /// Update scale with clamping, anchored to a point in canvas coordinates
       func zoom(to newScale: CGFloat, anchor: CGPoint) {
           let clampedScale = min(max(newScale, Self.minScale), Self.maxScale)
           guard clampedScale != scale else { return }

           // Adjust offset so anchor point stays fixed on screen
           let scaleDelta = clampedScale / scale
           offset.width = anchor.x - (anchor.x - offset.width) * scaleDelta
           offset.height = anchor.y - (anchor.y - offset.height) * scaleDelta
           scale = clampedScale
       }

       func updateCanvasSize(_ size: CGSize) {
           canvasSize = size
       }

       // Coordinate helpers
       func canvasToWorld(_ point: CGPoint) -> CGPoint
       func worldToCanvas(_ point: CGPoint) -> CGPoint
   }
   ```

2. `composer/Canvas/CoordinateTransform.swift`
   - Screen ↔ Canvas ↔ Node local conversions
   - Used by gesture handlers and edge rendering
   - Pure functions, no state

3. `composer/Canvas/GridBackground.swift`
   - SwiftUI `Canvas` view
   - Draw dots at 20pt intervals, scaled with zoom
   - White dots at 15% opacity on dark background
   - Uses `drawingGroup()` for performance

4. `composer/Canvas/FlowCanvasView.swift`
   ```swift
   /// PreferenceKey for canvas size (avoids mutating state in body)
   struct CanvasSizeKey: PreferenceKey {
       static var defaultValue: CGSize = .zero
       static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
           value = nextValue()
       }
   }

   struct FlowCanvasView: View {
       let flow: Flow
       @Environment(\.modelContext) private var modelContext
       @State private var canvasState = CanvasState()
       @State private var viewModel: FlowCanvasViewModel?

       var body: some View {
           GeometryReader { geometry in
               ZStack {
                   GridBackground(state: canvasState)
                   EdgeLayer(edges: flow.edges, state: canvasState)
                       .allowsHitTesting(false)
                   ConnectionPreview(state: canvasState)
                       .allowsHitTesting(false)
                   NodeLayer(nodes: flow.nodes, state: canvasState, viewModel: viewModel)
               }
               .preference(key: CanvasSizeKey.self, value: geometry.size)
               // Canvas gestures - disabled while editing text
               .gesture(canvasPanGesture, isEnabled: !canvasState.isEditingNode)
               .gesture(canvasZoomGesture, isEnabled: !canvasState.isEditingNode)
           }
           .onPreferenceChange(CanvasSizeKey.self) { size in
               canvasState.updateCanvasSize(size)
           }
           .task {
               viewModel = FlowCanvasViewModel(flow: flow, context: modelContext)
           }
       }

       private var canvasPanGesture: some Gesture {
           DragGesture()
               .onChanged { value in
                   canvasState.offset.width += value.translation.width
                   canvasState.offset.height += value.translation.height
               }
       }

       private var canvasZoomGesture: some Gesture {
           MagnifyGesture()
               .onChanged { value in
                   // Anchor zoom to gesture centroid
                   let anchor = value.startLocation
                   canvasState.zoom(to: value.magnification, anchor: anchor)
               }
       }
   }
   ```

### Phase 4: Edge Rendering

**Files to create:**

1. `composer/Canvas/EdgeLayer.swift`
   - SwiftUI `Canvas` view for performance
   - Draw bezier curves between port positions
   - Color based on edge dataType
   - Selected state with glow effect
   - Uses `drawingGroup()` modifier
   - Consider Metal fallback for 100+ edges

2. `composer/Canvas/ConnectionPreview.swift`
   - Temporary line during connection drag
   - Bezier from source port to cursor
   - Color matches source port type
   - Animated dashed stroke

3. `ConnectionPoint` struct:
   ```swift
   struct ConnectionPoint: Equatable {
       let nodeId: UUID
       let portId: String
       let portType: PortDataType
       let isOutput: Bool
       let position: CGPoint
   }
   ```

### Phase 5: Node Views

**Files to create:**

1. `composer/Nodes/NodeFrame.swift`
   ```swift
   struct NodeFrame<Content: View>: View {
       let icon: String
       let title: String
       let status: NodeStatus?
       @ViewBuilder let ports: () -> some View
       @ViewBuilder let content: () -> Content

       var body: some View {
           VStack(spacing: 0) {
               // Header
               HStack {
                   Image(systemName: icon)
                   Text(title)
                   Spacer()
                   if let status { StatusBadge(status) }
               }
               .padding(.horizontal, 12)
               .padding(.vertical, 8)

               // Ports
               ports()

               // Content
               content()
           }
           // iOS 26 Liquid Glass
           .glassEffect()
           .clipShape(RoundedRectangle(cornerRadius: 14))
           .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
       }
   }
   ```

2. `composer/Nodes/PortView.swift`
   - Colored circle (14px, 18px on hover)
   - Connection drag gesture
   - Opacity based on connection state
   - Hit target 44pt for accessibility
   - VoiceOver: "String output port, double tap to connect"

3. `composer/Nodes/NodeContainerView.swift`
   - Wraps node content
   - Uses transient position from ViewModel during drag
   - Selection border overlay
   - Tap to select (with modifier key support)
   - Context menu for delete
   - Explicit `.id(node.id)` for SwiftUI identity

4. `composer/Nodes/TextInputNodeView.swift`
   - Uses NodeFrame
   - TextEditor for content
   - One output port (string)

5. `composer/Nodes/PreviewOutputNodeView.swift`
   - Uses NodeFrame
   - Multiple input ports (string, image, audio)
   - Display area for previewing connected data

### Phase 6: Gesture System

**Gesture Priority & Conflict Resolution:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Priority (highest to lowest)                                    │
├─────────────────────────────────────────────────────────────────┤
│  1. TextEditor focus      → Captures all input, disables canvas │
│  2. Port connection drag  → highPriorityGesture on PortView     │
│  3. Node drag             → simultaneousGesture, wins via state │
│  4. Canvas pan/zoom       → lowest, disabled when editing       │
└─────────────────────────────────────────────────────────────────┘
```

**Conflict rules:**
- When `canvasState.isEditingNode == true`: Canvas pan/zoom disabled
- Port gestures use `.highPriorityGesture()` to win over node drag
- Node drag and selection use `.simultaneousGesture()` with state machine
- Canvas gestures only fire when hit test returns `.canvas`

**Files to create:**

1. `composer/Gestures/HitTester.swift`
   ```swift
   protocol HitTestable {
       func hitTest(_ point: CGPoint, transform: CoordinateTransform) -> HitTestResult
   }

   enum HitTestResult {
       case canvas
       case node(UUID)
       case port(nodeId: UUID, portId: String, isOutput: Bool)
       case edge(UUID)  // Hit tolerance: 8pt perpendicular distance from bezier
   }

   struct HitTester: HitTestable {
       let nodes: [FlowNode]
       let edges: [FlowEdge]
       let portRadius: CGFloat = 22  // 44pt touch target
       let edgeTolerance: CGFloat = 8  // px from curve

       func hitTest(_ point: CGPoint, transform: CoordinateTransform) -> HitTestResult

       /// Edge hit uses closest point on bezier curve
       private func distanceToEdge(_ edge: FlowEdge, from point: CGPoint) -> CGFloat
   }
   ```

2. `composer/Gestures/CanvasPanGesture.swift`
   - DragGesture on background (only when hit test = `.canvas`)
   - Updates `canvasState.offset`
   - Momentum/inertia via `withAnimation(.interactiveSpring)`
   - **Disabled** when `canvasState.isEditingNode == true`

3. `composer/Gestures/CanvasZoomGesture.swift`
   ```swift
   /// Zoom anchored to gesture centroid (trackpad) or pinch center (touch)
   MagnifyGesture()
       .onChanged { value in
           // macOS trackpad: anchor to cursor position
           // iOS: anchor to pinch midpoint
           let anchor = value.startLocation
           canvasState.zoom(to: canvasState.scale * value.magnification, anchor: anchor)
       }
   ```
   - Scale clamped to `0.25...2.0`
   - Anchor point stays fixed on screen during zoom
   - **Disabled** when `canvasState.isEditingNode == true`

4. `composer/Gestures/NodeDragGesture.swift`
   - Uses `.simultaneousGesture()` to coexist with tap-to-select
   - Updates transient position in ViewModel (not SwiftData)
   - Only commits to SwiftData on gesture end
   - Multi-node drag: moves all selected nodes together

5. `composer/Gestures/ConnectionGesture.swift`
   - Uses `.highPriorityGesture()` on PortView to win over node drag
   - DragGesture from port
   - Track position in canvas coordinates
   - Highlight compatible target ports
   - Validate and create edge on drop

6. `composer/Gestures/SelectionGesture.swift`
   - Tap to select single (clears other selections)
   - Cmd+Tap (macOS) / long-press (iOS) for multi-select
   - Tap on canvas clears all selections
   - Marquee selection (stretch goal)

7. `composer/Gestures/TextEditingCoordinator.swift`
   ```swift
   /// Manages focus state for TextEditor in nodes
   @MainActor @Observable
   final class TextEditingCoordinator {
       weak var canvasState: CanvasState?

       func beginEditing(nodeId: UUID) {
           canvasState?.isEditingNode = true
       }

       func endEditing() {
           canvasState?.isEditingNode = false
       }
   }
   ```

### Phase 7: Accessibility

**Files to create:**

1. `composer/Accessibility/NodeAccessibility.swift`
   ```swift
   extension NodeContainerView {
       var accessibilityLabel: Text {
           Text("\(node.nodeType.displayName) node: \(node.label)")
       }

       var accessibilityActions: some View {
           self
               .accessibilityAction(named: "Delete") { viewModel.delete() }
               .accessibilityAction(named: "Connect Output") { beginConnection() }
       }
   }
   ```

2. `composer/Accessibility/CanvasAccessibility.swift`
   - Custom rotor for node navigation
   - Announce selection changes
   - Describe connections

### Phase 8: Integration

**Files to modify:**

1. `composer/composerApp.swift`
   ```swift
   @main
   struct ComposerApp: App {
       let container: ModelContainer

       init() {
           let schema = Schema([Flow.self, FlowNode.self, FlowEdge.self])
           let config = ModelConfiguration(isStoredInMemoryOnly: false)
           container = try! ModelContainer(for: schema, configurations: config)

           // Enable undo support
           container.mainContext.undoManager = UndoManager()
       }

       var body: some Scene {
           WindowGroup {
               ContentView()
           }
           .modelContainer(container)
       }
   }
   ```

2. `composer/ContentView.swift`
   - Replace placeholder with FlowCanvasView
   - Add toolbar with Liquid Glass styling
   - Query flow from SwiftData
   - Undo/Redo buttons wired to context.undoManager

---

## Edge Selection & Deletion (MVP)

**Selection:**
- Click/tap on edge (8pt hit tolerance from bezier curve)
- Selected edge shows thicker stroke + glow effect
- Only one edge selected at a time (edges can't multi-select with nodes)
- Clicking canvas or node clears edge selection

**Deletion:**
- **macOS**: `Delete` or `Backspace` key deletes selected edge
- **iOS**: Tap selected edge again to show "Delete" context menu
- Undo supported via SwiftData `UndoManager`

**Visual feedback:**
```swift
extension EdgeLayer {
    func strokeStyle(for edge: FlowEdge, isSelected: Bool) -> StrokeStyle {
        StrokeStyle(
            lineWidth: isSelected ? 3 : 2,
            lineCap: .round
        )
    }

    func glowEffect(for edge: FlowEdge, isSelected: Bool) -> some View {
        if isSelected {
            edgePath(for: edge)
                .stroke(edge.dataType.color.opacity(0.5), lineWidth: 8)
                .blur(radius: 4)
        }
    }
}
```

---

## Key Implementation Details

### Port Colors (from web app CSS)
```swift
extension PortDataType {
    var color: Color {
        switch self {
        case .string: Color(red: 0.56, green: 0.78, blue: 0.96)  // Soft azure
        case .image:  Color(red: 0.79, green: 0.72, blue: 0.98)  // Lavender
        case .audio:  Color(red: 0.56, green: 0.96, blue: 0.89)  // Electric mint
        case .pulse:  Color(red: 0.96, green: 0.78, blue: 0.56)  // Apricot
        }
    }
}
```

### Node Styling (Liquid Glass - iOS 26+)
```swift
// Primary approach - use system glass
.glassEffect()

// Fallback for custom glass (if needed)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 14))
.shadow(color: .black.opacity(0.3), radius: 8, y: 4)
```

### Bezier Edge Path
```swift
func edgePath(from start: CGPoint, to end: CGPoint) -> Path {
    var path = Path()
    path.move(to: start)

    let controlOffset = max(abs(end.x - start.x) * 0.5, 50)
    let control1 = CGPoint(x: start.x + controlOffset, y: start.y)
    let control2 = CGPoint(x: end.x - controlOffset, y: end.y)

    path.addCurve(to: end, control1: control1, control2: control2)
    return path
}
```

### Gesture Priority
1. Port drag (highest) - starts connection
2. Node drag - moves node (transient state)
3. Canvas drag (lowest) - pans viewport

### Transient Drag Pattern
```swift
// During drag - update ViewModel only (no SwiftData writes)
func onDragChanged(_ value: DragGesture.Value) {
    viewModel.updateNodeDrag(node.id, to: newPosition)
}

// On drag end - commit to SwiftData once
func onDragEnded(_ value: DragGesture.Value) {
    viewModel.endNodeDrag(node.id)  // Single write
}
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| Incompatible port connection | Show shake animation, toast message |
| Circular connection | Prevent, show error indicator |
| Missing required port | Validation badge on node |
| SwiftData save failure | Retry with exponential backoff, alert user |

---

## Testing Strategy

### Unit Tests
- `HitTester` geometry calculations
- `CoordinateTransform` conversions
- `FlowCanvasViewModel` operations
- Port compatibility validation

### UI Tests
- Node creation and positioning
- Connection creation via drag
- Selection and multi-selection
- Undo/redo operations

### Previews
- Each node type with sample data
- Canvas with pre-populated flow
- Edge layer with various configurations

---

## Files Modified

| File | Action |
|------|--------|
| `composer/composerApp.swift` | Add SwiftData schema + UndoManager |
| `composer/ContentView.swift` | Replace with canvas |
| `composer/Item.swift` | Delete (unused placeholder) |

## Files Created

| File | Purpose |
|------|---------|
| `composer/Models/Flow.swift` | Flow SwiftData model |
| `composer/Models/FlowNode.swift` | Node model with relationships |
| `composer/Models/FlowEdge.swift` | Edge model with node relationships |
| `composer/Models/NodeType.swift` | Node type enum |
| `composer/Models/PortDefinition.swift` | Port types and colors |
| `composer/Models/NodePortSchemas.swift` | Port definitions per type |
| `composer/ViewModels/FlowCanvasViewModel.swift` | Canvas orchestration |
| `composer/ViewModels/NodeViewModel.swift` | Node transient state |
| `composer/ViewModels/ConnectionViewModel.swift` | Connection management |
| `composer/Canvas/CanvasState.swift` | Observable canvas state |
| `composer/Canvas/CoordinateTransform.swift` | Coordinate conversions |
| `composer/Canvas/FlowCanvasView.swift` | Main canvas container |
| `composer/Canvas/GridBackground.swift` | Dot grid background |
| `composer/Canvas/EdgeLayer.swift` | Edge rendering |
| `composer/Canvas/ConnectionPreview.swift` | Drag connection line |
| `composer/Nodes/NodeFrame.swift` | Liquid Glass node chrome |
| `composer/Nodes/PortView.swift` | Port handle view |
| `composer/Nodes/NodeContainerView.swift` | Node wrapper |
| `composer/Nodes/TextInputNodeView.swift` | Text input node |
| `composer/Nodes/PreviewOutputNodeView.swift` | Preview output node |
| `composer/Gestures/HitTester.swift` | Protocol-based hit testing |
| `composer/Gestures/CanvasPanGesture.swift` | Pan gesture |
| `composer/Gestures/CanvasZoomGesture.swift` | Zoom with anchor |
| `composer/Gestures/NodeDragGesture.swift` | Node drag gesture |
| `composer/Gestures/ConnectionGesture.swift` | Connection gesture |
| `composer/Gestures/SelectionGesture.swift` | Selection gesture |
| `composer/Gestures/TextEditingCoordinator.swift` | Focus state management |
| `composer/Accessibility/NodeAccessibility.swift` | Node VoiceOver |
| `composer/Accessibility/CanvasAccessibility.swift` | Canvas rotor |

---

## Reference Files

- `~/dev/composer/types/flow.ts` - Node/Edge type definitions
- `~/dev/composer/app/styles/nodes.css` - Visual design tokens
- `~/dev/composer/components/Flow/AgentFlow.tsx` - Canvas patterns
- `docs/NATIVE_APP_CONTEXT.md` - Backend context

---

## Design Decisions

| Question | Decision |
|----------|----------|
| Width/height persisted? | **No** - measured dynamically via `onGeometryChange()`, cached in `NodeViewModel.measuredSize`. Avoids stale data when content changes. |
| Edge selection in MVP? | **Yes** - single edge selection with Delete key (macOS) or context menu (iOS). |
| Port ID stability? | **Yes** - explicit string constants in `PortID` enum. Never rename or reorder. Edges reference by ID, not index. |
| macOS trackpad zoom? | Anchored to cursor position via `MagnifyGesture.startLocation`. Scale clamped 0.25–2.0. |

---

## Future Phases (Not in Scope)

1. Additional node types (13 remaining)
2. Supabase sync and real-time collaboration
3. Flow execution with NDJSON streaming
4. Copy/paste nodes
5. Full keyboard shortcuts (beyond Delete)
6. Metal-backed edge rendering for large flows
7. Marquee selection
