//
//  TouchManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/01.
//

import UIKit

typealias TouchHashValue = Int

final class TouchManager {

    private (set) var touchPointsDictionary: [TouchHashValue: [TouchPoint]] = [:]

    func appendFingerTouches(_ event: UIEvent?, in view: UIView) {
        event?.allTouches?.forEach { touch in
            let hashValue: TouchHashValue = touch.hashValue

            if touch.phase == .began && touchPointsDictionary[hashValue] == nil {
                touchPointsDictionary[hashValue] = []
            }

            if touchPointsDictionary.keys.contains(hashValue) {
                let touchPoint = TouchPoint(touch: touch, view: view)
                touchPointsDictionary[hashValue]?.append(touchPoint)
            }
        }
    }

    func appendPencilTouches(_ event: UIEvent?, in view: UIView) {
        event?.allTouches?.forEach { touch in
            let hashValue: TouchHashValue = touch.hashValue

            if touch.phase == .began && touchPointsDictionary[hashValue] == nil {
                touchPointsDictionary[hashValue] = []
            }

            if touchPointsDictionary.keys.contains(hashValue),
               let coalescedTouches = event?.coalescedTouches(for: touch) {

                for index in 0 ..< coalescedTouches.count {
                    let touchPoint = TouchPoint(touch: coalescedTouches[index], view: view)
                    touchPointsDictionary[hashValue]?.append(touchPoint)
                }
            }
        }
    }

    func removeIfTouchPhaseIsEnded(touches: Set<UITouch>) {
        for touch in touches where touch.phase == .ended {
            let hashValue: TouchHashValue = touch.hashValue
            touchPointsDictionary.removeValue(forKey: hashValue)
        }
    }

}

extension TouchManager {

    func getTouchPoints(with hashValue: TouchHashValue) -> [TouchPoint]? {
        touchPointsDictionary[hashValue]
    }

    func getTouchPointsDictionary(_ hashValues: [TouchHashValue]) -> [TouchHashValue: [TouchPoint]] {
        return Dictionary(uniqueKeysWithValues: hashValues.compactMap { hashValue in
            touchPointsDictionary[hashValue].map { (hashValue, $0) }
        })
    }
    func getTouchPhases(_ hashValues: [TouchHashValue]) -> [UITouch.Phase?] {
        hashValues.compactMap {
            touchPointsDictionary[$0]?.last
        }
        .compactMap { $0?.phase }
    }

    func getLatestTouchPhase(with hashValue: TouchHashValue) -> UITouch.Phase? {
        touchPointsDictionary[hashValue]?.last?.phase
    }
    func getLatestTouchPoint(with hashValue: TouchHashValue) -> TouchPoint? {
        touchPointsDictionary[hashValue]?.last
    }

}
