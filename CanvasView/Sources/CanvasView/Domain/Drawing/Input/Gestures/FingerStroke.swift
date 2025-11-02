//
//  FingerStroke.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

/// A class that manages the finger position information sent from the device
@MainActor final class FingerStroke {

    /// A dictionary that manages points input from multiple fingers
    private(set) var touchHistories: TouchHistoriesOnScreen = [:]

    /// A ID currently in use in the finger drawing
    private(set) var drawingTouchID: TouchID?

    /// A variable used to get elements from the array starting from the next element after this point
    private(set) var activeLatestTouchPoint: TouchPoint?

    convenience init(
        touchHistories: TouchHistoriesOnScreen,
        activeLatestTouchPoint: TouchPoint? = nil
    ) {
        self.init()
        self.touchHistories = touchHistories
        self.activeLatestTouchPoint = activeLatestTouchPoint
    }
}

extension FingerStroke {

    var isAllFingersOnScreen: Bool {
        !touchHistories.keys.contains { key in
            // If the last element of the array is `ended` or `cancelled`, it means that a finger has been lifted.
            UITouch.isTouchCompleted(touchHistories[key]?.last?.phase ?? .cancelled)
        }
    }

    var isFingerDrawingInactive: Bool {
        drawingTouchID == nil
    }

    var latestTouchPoints: [TouchPoint] {
        guard
            let drawingTouchID,
            let touchArray = touchHistories[drawingTouchID]
        else { return [] }

        var latestTouchArray: [TouchPoint] = []

        if let activeLatestTouchPoint {
            latestTouchArray = touchArray.elements(after: activeLatestTouchPoint) ?? []
        } else {
            latestTouchArray = touchArray
        }

        if let lastLatestTouchArray = latestTouchArray.last {
            activeLatestTouchPoint = lastLatestTouchArray
        }

        return latestTouchArray
    }

    func startFingerDrawing() {
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
                UITouch.isTouchCompleted(touchHistories[$0]?.lastTouchPhase ?? .cancelled)
            }
            .forEach {
                touchHistories.removeValue(forKey: $0)
            }
    }

    func reset() {
        touchHistories = [:]
        drawingTouchID = nil
        activeLatestTouchPoint = nil
    }
}
