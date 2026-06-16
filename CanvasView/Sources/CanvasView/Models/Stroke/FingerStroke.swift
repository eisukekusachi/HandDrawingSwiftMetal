//
//  FingerStroke.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

/// Manages the finger position information sent from the device.
final class FingerStroke {

    /// A dictionary that manages points input from multiple fingers
    private(set) var touchHistories: TouchHistoriesOnScreen = [:]

    /// A ID currently in use in the finger drawing
    private(set) var drawingTouchID: TouchID?

    /// The last touch point that was drawn.
    private(set) var lastDrawnTouchPoint: TouchPoint?

    convenience init(
        touchHistories: TouchHistoriesOnScreen = [:],
        lastDrawnTouchPoint: TouchPoint? = nil
    ) {
        self.init()
        self.touchHistories = touchHistories
        self.lastDrawnTouchPoint = lastDrawnTouchPoint
    }
}

extension FingerStroke {

    var hasActiveTouches: Bool {
        touchHistories.values.contains {
            guard let phase = $0.last?.phase else { return false }
            return phase != .ended && phase != .cancelled
        }
    }

    var isFingerDrawingInactive: Bool {
        drawingTouchID == nil
    }

    var isCancelled: Bool {
        guard let drawingTouchID else { return false }
        return touchHistories[drawingTouchID]?.last?.phase == .cancelled
    }

    func shouldFinalizeDrawing(from pointArray: [TouchPoint]) -> Bool {
        if TouchPhase.shouldFinalizeDrawing(from: pointArray) {
            return true
        }

        guard let drawingTouchID,
              let phase = touchHistories[drawingTouchID]?.last?.phase
        else { return false }

        return phase == .ended || phase == .cancelled
    }

    /// Gets points from the specified start element to the end
    func drawingPoints(after touchPoint: TouchPoint?) -> [TouchPoint] {
        guard
            let drawingTouchID,
            let touchArray = touchHistories[drawingTouchID]
        else { return [] }

        var result: [TouchPoint] = []

        if let touchPoint {
            result = touchArray.elements(after: touchPoint) ?? []
        } else {
            result = touchArray
        }

        return result
    }

    /// Sets `lastDrawnTouchPoint` to the last touch point in the drawing history.
    func setLastDrawnTouchPoint() {
        guard
            let drawingTouchID,
            let touchPointArray = touchHistories[drawingTouchID]
        else { return }

        if let touchPoint = touchPointArray.last {
            lastDrawnTouchPoint = touchPoint
        }
    }

    /// Sets `drawingTouchID` from the touch history key used for drawing.
    /// `touchHistories` should contain only one element when a stroke begins.
    func setDrawingTouchID() {
        drawingTouchID = touchHistories.keys.first
    }

    func appendTouchPointToDictionary(_ touches: TouchesOnScreen) {
        touches.keys.forEach { key in
            if !touchHistories.keys.contains(key) {
                touchHistories[key] = []
            }
            if let value = touches[key] {
                touchHistories[key]?.append(value)
            }
        }
    }

    func removeUnusedTouchArrayFromDictionary() {
        touchHistories.keys
            .filter {
                touchHistories[$0]?.currentTouchPhase == .ended ||
                touchHistories[$0]?.currentTouchPhase == .cancelled
            }
            .forEach {
                touchHistories.removeValue(forKey: $0)
            }
    }

    func reset() {
        touchHistories = [:]
        drawingTouchID = nil
        lastDrawnTouchPoint = nil
    }
}
