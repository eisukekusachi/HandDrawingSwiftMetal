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

    /// A key currently in use in the finger touch dictionary
    private var dictionaryKey: CanvasTouchHashValue?

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

    var latestTouchPoints: [CanvasTouchPoint] {
        guard
            let dictionaryKey,
            let touchPoints = touchArrayDictionary[dictionaryKey]
        else { return [] }

        let latestTouchPoints = touchPoints.elements(after: latestTouchPoint) ?? touchPoints
        latestTouchPoint = latestTouchPoints.last

        return latestTouchPoints
    }

    var isFingersOnScreen: Bool {
        !touchArrayDictionary.keys.contains { key in
            [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(
                touchArrayDictionary[key]?.last?.phase ?? .cancelled
            )
        }
    }

    func updateDictionaryKeyIfKeyIsNil() {
        guard
            let key = touchArrayDictionary.keys.first,
            dictionaryKey == nil
        else { return }

        dictionaryKey = key
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

    func removeTouchArrayFromDictionaryIfLastElementMatches(phases conditions: [UITouch.Phase]) {
        touchArrayDictionary.keys
            .filter { conditions.contains(touchArrayDictionary[$0]?.currentTouchPhase ?? .cancelled) }
            .forEach { touchArrayDictionary.removeValue(forKey: $0) }
    }

    func reset() {
        touchArrayDictionary = [:]
        dictionaryKey = nil
    }

}

