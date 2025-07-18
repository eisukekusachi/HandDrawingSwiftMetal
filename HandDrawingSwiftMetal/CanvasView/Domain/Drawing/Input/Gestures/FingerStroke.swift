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
    private(set) var touchArrayDictionary: [TouchHashValue: [TouchPoint]] = [:]

    /// A key currently in use in the finger touch dictionary
    private(set) var activeDictionaryKey: TouchHashValue?

    /// A variable used to get elements from the array starting from the next element after this point
    private(set) var activeLatestTouchPoint: TouchPoint?

    convenience init(
        touchArrayDictionary: [TouchHashValue: [TouchPoint]],
        activeDictionaryKey: TouchHashValue? = nil,
        activeLatestTouchPoint: TouchPoint? = nil
    ) {
        self.init()
        self.touchArrayDictionary = touchArrayDictionary
        self.activeDictionaryKey = activeDictionaryKey
        self.activeLatestTouchPoint = activeLatestTouchPoint
    }

}

extension FingerStroke {

    var isAllFingersOnScreen: Bool {
        !touchArrayDictionary.keys.contains { key in
            // If the last element of the array is `ended` or `cancelled`, it means that a finger has been lifted.
            UITouch.isTouchCompleted(touchArrayDictionary[key]?.last?.phase ?? .cancelled)
        }
    }

    var latestTouchPoints: [TouchPoint] {
        guard
            let activeDictionaryKey,
            let touchArray = touchArrayDictionary[activeDictionaryKey]
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

    func setActiveDictionaryKeyIfNil() {
        // If the gesture is determined to be drawing and `setActiveDictionaryKeyIfNil()` is called,
        // `touchArrayDictionary` should contain only one element, so the first key is simply set.
        guard
            // The first element of the sorted key array in the Dictionary is set as the active key.
            let firstKey = touchArrayDictionary.keys.sorted().first,
            activeDictionaryKey == nil
        else { return }

        activeDictionaryKey = firstKey
    }

    func appendTouchPointToDictionary(_ touchPoints: [TouchHashValue: TouchPoint]) {
        touchPoints.keys.forEach { key in
            if !touchArrayDictionary.keys.contains(key) {
                touchArrayDictionary[key] = []
            }
            if let value = touchPoints[key] {
                touchArrayDictionary[key]?.append(value)
            }
        }
    }

    func removeEndedTouchArrayFromDictionary() {
        touchArrayDictionary.keys
            .filter {
                UITouch.isTouchCompleted(touchArrayDictionary[$0]?.lastTouchPhase ?? .cancelled)
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
