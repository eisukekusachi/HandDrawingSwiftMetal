//
//  TouchPhase.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/08.
//

import UIKit

/// A `Sendable` of `UITouch.Phase`
/// https://developer.apple.com/documentation/uikit/uitouch/phase-swift.enum
public enum TouchPhase : Int, Sendable {

    case began = 0

    case moved = 1

    case stationary = 2

    case ended = 3

    case cancelled = 4

    @available(iOS 13.4, *)
    case regionEntered = 5

    @available(iOS 13.4, *)
    case regionMoved = 6

    @available(iOS 13.4, *)
    case regionExited = 7
}

public extension TouchPhase {
    init(_ phase: UITouch.Phase) {
        switch phase {
        case .began: self = .began
        case .moved: self = .moved
        case .stationary: self = .stationary
        case .ended: self = .ended
        case .cancelled: self = .cancelled
        case .regionEntered: self = .regionEntered
        case .regionMoved: self = .regionMoved
        case .regionExited: self = .regionExited
        @unknown default:
            self = .cancelled  // or .ended / some fallback
        }
    }
}

extension TouchPhase {

    /// Touch phase used for drawing
    static func drawingTouchPhase(_ points: [TouchPoint]) -> UITouch.Phase? {
        if points.contains(where: { $0.phase == .cancelled }) {
            return .cancelled
        } else if points.contains(where: { $0.phase == .ended }) {
            return .ended
        } else if points.contains(where: { $0.phase == .began }) {
            return .began
        } else if points.contains(where: { $0.phase == .moved }) {
            return .moved
        } else if points.contains(where: { $0.phase == .stationary }) {
            return .stationary
        }
        return nil
    }
}
