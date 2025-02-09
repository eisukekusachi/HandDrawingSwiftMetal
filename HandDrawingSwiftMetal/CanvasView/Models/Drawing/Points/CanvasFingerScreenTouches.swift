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
    private(set) var activeDictionaryKey: CanvasTouchHashValue?

    /// A variable used to get elements from the array starting from the next element after this point
    private var activeLatestTouchPoint: CanvasTouchPoint?

    convenience init(touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) {
        self.init()
        self.touchArrayDictionary = touchArrayDictionary
    }

}

extension CanvasFingerScreenTouches {

    var latestTouchPoints: [CanvasTouchPoint] {
        guard
            let activeDictionaryKey,
            let touchArray = touchArrayDictionary[activeDictionaryKey]
        else { return [] }

        let latestTouchArray: [CanvasTouchPoint] = activeLatestTouchPoint.map {
            touchArray.elements(after: $0) ?? []
        } ?? touchArray

        if let lastLatestTouchArray = latestTouchArray.last {
            activeLatestTouchPoint = lastLatestTouchArray
        }

        return latestTouchArray
    }

    var isFingersOnScreen: Bool {
        !touchArrayDictionary.keys.contains { key in
            // If the last element of the array is `ended` or `cancelled`, it means that a finger has been lifted.
            [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(
                touchArrayDictionary[key]?.last?.phase ?? .cancelled
            )
        }
    }

    func updateActiveDictionaryKeyIfKeyIsNil() {
        // If the gesture is determined to be drawing and `updateActiveDictionaryKeyIfKeyIsNil()` is called,
        // `touchArrayDictionary` should contain only one element, so the first key is simply set.
        guard
            // The first element of the sorted key array in the Dictionary is set as the active key.
            let firstKey = touchArrayDictionary.keys.sorted().first,
            activeDictionaryKey == nil
        else { return }

        activeDictionaryKey = firstKey
    }

    func appendTouchPointToDictionary(_ touches: [CanvasTouchHashValue: CanvasTouchPoint]) {
        touches.keys.forEach { key in
            if !touchArrayDictionary.keys.contains(key) {
                touchArrayDictionary[key] = []
            }
            if let value = touches[key] {
                touchArrayDictionary[key]?.append(value)
            }
        }
    }

    func removeEndedTouchArrayFromDictionary() {
        touchArrayDictionary.keys
            .filter {
                [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(touchArrayDictionary[$0]?.currentTouchPhase ?? .cancelled)
            }
            .forEach {
                touchArrayDictionary.removeValue(forKey: $0)
            }
    }

    func reset() {
        touchArrayDictionary = [:]
        activeDictionaryKey = nil
        activeLatestTouchPoint = nil
    }

}

