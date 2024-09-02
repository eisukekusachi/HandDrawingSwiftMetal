//
//  FingerScreenTouchManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

final class FingerScreenTouchManager {

    private (set) var touchArrayDictionary: [TouchHashValue: [TouchPoint]] = [:]

    /// A key currently used in the Dictionary
    var currentDictionaryKey: TouchHashValue?

    /// A variable used to get elements from the array starting from the next element after this point
    var latestCanvasTouchPoint: TouchPoint?

}

extension FingerScreenTouchManager {
    var isEmpty: Bool {
        touchArrayDictionary.isEmpty
    }

    func append(
        event: UIEvent?,
        in view: UIView
    ) {
        event?.allTouches?.forEach { touch in
            guard touch.type != .pencil else { return }

            let key: TouchHashValue = touch.hashValue

            if touch.phase == .began {
                touchArrayDictionary[key] = []
            }
            touchArrayDictionary[key]?.append(
                .init(
                    touch: touch,
                    view: view
                )
            )
        }
    }

    func getTouchPoints(for key: TouchHashValue) -> [TouchPoint] {
        touchArrayDictionary[key] ?? []
    }

    func removeIfLastElementMatches(phases conditions: [UITouch.Phase]) {
        touchArrayDictionary.keys.forEach { key in
            if let touches = touchArrayDictionary[key] {
                if let lastTouch = touches.last,
                   conditions.contains(lastTouch.phase) {
                    touchArrayDictionary.removeValue(forKey: key)
                }
            }
        }
    }

    func reset() {
        touchArrayDictionary = [:]
        currentDictionaryKey = nil
        latestCanvasTouchPoint = nil
    }

}

