//
//  ResizeHandle.swift
//  composer
//
//  Draggable resize handle for sidebar width adjustment
//

import SwiftUI

/// Drag handle on the left edge of the sidebar for resizing
struct ResizeHandle: View {
    @Binding var width: CGFloat

    @State private var isDragging = false

    private let handleWidth: CGFloat = 6

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: handleWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        // Dragging left (negative translation) increases width
                        // Dragging right (positive translation) decreases width
                        let newWidth = width - value.translation.width
                        width = min(PreviewSidebarState.maxWidth,
                                  max(PreviewSidebarState.minWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            #if os(macOS)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif
            .overlay {
                // Visual indicator when dragging
                if isDragging {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 2)
                }
            }
    }
}

#Preview {
    HStack(spacing: 0) {
        Color.blue.opacity(0.3)

        ZStack(alignment: .leading) {
            Color.gray.opacity(0.3)
                .frame(width: 340)

            ResizeHandle(width: .constant(340))
        }
    }
    .frame(width: 600, height: 400)
}
