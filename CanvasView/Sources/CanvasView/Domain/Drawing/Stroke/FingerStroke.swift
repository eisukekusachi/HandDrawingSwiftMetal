//
//  FingerStroke.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

/// A class that manages the finger position information sent from the device
final class FingerStroke {

    /// A dictionary that manages points input from multiple fingers
    private(set) var touchHistories: TouchHistoriesOnScreen = [:]

    /// A ID currently in use in the finger drawing
    private(set) var drawingTouchID: TouchID?

    /// End point of the drawing line
    private(set) var drawingLineEndPoint: TouchPoint?

    convenience init(
        touchHistories: TouchHistoriesOnScreen = [:],
        drawingLineEndPoint: TouchPoint? = nil
    ) {
        self.init()
        self.touchHistories = touchHistories
        self.drawingLineEndPoint = drawingLineEndPoint
    }
}

extension FingerStroke {

    var hasEndedTouches: Bool {
        touchHistories.keys.contains { key in
            touchHistories[key]?.last?.phase == .ended
        }
    }

    var isFingerDrawingInactive: Bool {
        drawingTouchID == nil
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

    /// Stores the line endpoint
    func updateDrawingLineEndPoint() {
        guard
            let drawingTouchID,
            let touchPointArray = touchHistories[drawingTouchID]
        else { return }

        if let touchPoint = touchPointArray.last {
            drawingLineEndPoint = touchPoint
        }
    }

    func setStoreKeyForDrawing() {
        // `touchHistories` should contain only one element, so the first key is simply set.
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

    func removeEndedTouchArrayFromDictionary() {
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
        drawingLineEndPoint = nil
    }
}
