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

    convenience init(touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) {
        self.init()
        self.touchArrayDictionary = touchArrayDictionary
    }

}

extension CanvasFingerScreenTouches {
    var isEmpty: Bool {
        touchArrayDictionary.isEmpty
    }

    var hasFingerLiftedOffScreen: Bool {
        touchArrayDictionary.keys.contains { key in
            guard let lastTouchPhase = touchArrayDictionary[key]?.last?.phase else {
                return false
            }
            return [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(lastTouchPhase)
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
    }

}

