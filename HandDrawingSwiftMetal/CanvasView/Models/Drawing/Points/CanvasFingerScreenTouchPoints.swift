//
//  CanvasFingerScreenTouchPoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

final class CanvasFingerScreenTouchPoints {

    private (set) var touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]] = [:]

    /// A key currently used in the Dictionary
    var currentDictionaryKey: CanvasTouchHashValue?

    /// A variable used to get elements from the array starting from the next element after this point
    private var latestTouchPoint: CanvasTouchPoint?

}

extension CanvasFingerScreenTouchPoints {
    var isEmpty: Bool {
        touchArrayDictionary.isEmpty
    }

    var isTouchEnded: Bool {
        touchArrayDictionary.containsPhases([.ended])
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
        currentDictionaryKey = nil
        latestTouchPoint = nil
    }

}

