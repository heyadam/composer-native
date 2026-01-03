//
//  CoordinateTransform.swift
//  composer
//
//  Coordinate conversion utilities (pure functions)
//

import Foundation
import CoreGraphics

/// Coordinate transformation utilities for the canvas
enum CoordinateTransform {
    /// Convert a point from screen space to world space
    static func screenToWorld(_ point: CGPoint, offset: CGSize, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: (point.x - offset.width) / scale,
            y: (point.y - offset.height) / scale
        )
    }

    /// Convert a point from world space to screen space
    static func worldToScreen(_ point: CGPoint, offset: CGSize, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x * scale + offset.width,
            y: point.y * scale + offset.height
        )
    }

    /// Convert a size from world space to screen space
    static func worldToScreenSize(_ size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    /// Convert a size from screen space to world space
    static func screenToWorldSize(_ size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(
            width: size.width / scale,
            height: size.height / scale
        )
    }

    /// Get the transform matrix for rendering world content to screen
    static func worldToScreenTransform(offset: CGSize, scale: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: offset.width, y: offset.height)
            .scaledBy(x: scale, y: scale)
    }

    /// Convert a rect from world space to screen space
    static func worldToScreenRect(_ rect: CGRect, offset: CGSize, scale: CGFloat) -> CGRect {
        let origin = worldToScreen(rect.origin, offset: offset, scale: scale)
        let size = worldToScreenSize(rect.size, scale: scale)
        return CGRect(origin: origin, size: size)
    }

    /// Convert a rect from screen space to world space
    static func screenToWorldRect(_ rect: CGRect, offset: CGSize, scale: CGFloat) -> CGRect {
        let origin = screenToWorld(rect.origin, offset: offset, scale: scale)
        let size = screenToWorldSize(rect.size, scale: scale)
        return CGRect(origin: origin, size: size)
    }

    /// Calculate the visible world rect for a given canvas size
    static func visibleWorldRect(canvasSize: CGSize, offset: CGSize, scale: CGFloat) -> CGRect {
        screenToWorldRect(
            CGRect(origin: .zero, size: canvasSize),
            offset: offset,
            scale: scale
        )
    }
}
