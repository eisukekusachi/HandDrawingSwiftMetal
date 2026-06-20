//
//  StrokePointState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/20.
//

import UIKit

/// Gets the current drawing state from a touch point array for one stroke input.
struct StrokePointState {

    let points: [TouchPoint]

    /// `true` when the points indicate that drawing should be finalized.
    var shouldFinalizeDrawing: Bool {
        if let phase = drawingTouchPhase,
           phase == .ended || phase == .cancelled {
            return true
        }

        return points.last?.phase == .ended || points.last?.phase == .cancelled
    }

    /// Aggregated touch phase for the points, with cancelled taking priority.
    var drawingTouchPhase: UITouch.Phase? {
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
