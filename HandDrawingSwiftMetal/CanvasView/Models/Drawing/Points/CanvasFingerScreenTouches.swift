//
//  CanvasFingerScreenTouches.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

/// A class that manages touch points from multiple finger inputs on the screen
final class CanvasFingerScreenTouches {

    /// A dictionary that manages points input from multiple fingers
    private(set) var touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]] = [:]

    /// A key currently used in the Dictionary
    var dictionaryKey: CanvasTouchHashValue?

    /// A variable used to get elements from the array starting from the next element after this point
    private(set) var latestTouchPoint: CanvasTouchPoint?

    convenience init(touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) {
        self.init()
        self.touchArrayDictionary = touchArrayDictionary
    }

}

extension CanvasFingerScreenTouches {
    var isEmpty: Bool {
        touchArrayDictionary.isEmpty
    }

    var hasFingersLiftedOffScreen: Bool {
        touchArrayDictionary.keys.contains { key in
            guard let lastTouchPhase = touchArrayDictionary[key]?.last?.phase else {
                return false
            }
            return [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(lastTouchPhase)
        }
    }

    func updateDictionaryKeyIfKeyIsNil() {
        if dictionaryKey == nil {
            dictionaryKey = touchArrayDictionary.keys.first
        }
    }
    func appendTouches(_ touches: [CanvasTouchHashValue: CanvasTouchPoint]) {
        touches.keys.forEach { key in
            if !touchArrayDictionary.keys.contains(key) {
                touchArrayDictionary[key] = []
            }
            if let value = touches[key] {
                touchArrayDictionary[key]?.append(value)
            }
        }
    }

    func getLatestTouchPoints(for key: CanvasTouchHashValue) -> [CanvasTouchPoint]? {
        guard let touchPoints = touchArrayDictionary[key] else { return nil }

        let latestTouchPoints = touchPoints.elements(after: latestTouchPoint) ?? touchPoints
        latestTouchPoint = latestTouchPoints.last

        return latestTouchPoints
    }

    func removeIfLastElementMatches(phases conditions: [UITouch.Phase]) {
        touchArrayDictionary.keys.forEach { key in
            if let touchArray = touchArrayDictionary[key],
                conditions.contains(touchArray.currentTouchPhase) {
                touchArrayDictionary.removeValue(forKey: key)
            }
        }
    }

    func reset() {
        touchArrayDictionary = [:]
        dictionaryKey = nil
        latestTouchPoint = nil
    }

}

