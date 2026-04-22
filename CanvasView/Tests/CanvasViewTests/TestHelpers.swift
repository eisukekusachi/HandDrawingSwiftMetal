//
//  TestHelpers.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2026/01/03.
//

import Foundation
import UIKit

@testable import CanvasView

/// Repeatedly evaluates `condition` at the given interval until it becomes `true` or the timeout is reached
struct TestHelpers {

    static func waitUntil(
        _ condition: () -> Bool,
        interval: UInt64 = 10_000_000,   // 10ms
        timeout: UInt64 = 500_000_000    // 500ms
    ) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeout {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: interval)
        }
        return condition()
    }

    /// Creates a stable `TouchID` for unit tests.
    ///
    /// `TouchID` is based on `ObjectIdentifier(UITouch)`, so tests need a real touch instance.
    @MainActor
    static func makeTouchID(seed: Int) -> TouchID {
        let touch = UITouchDummy(
            location: .zero,
            previousLocation: .zero,
            majorRadius: 0,
            majorRadiusTolerance: 0,
            preciseLocation: .zero,
            precisePreviousLocation: .zero,
            tapCount: 0,
            timestamp: TimeInterval(seed),
            type: .direct,
            phase: .began,
            force: 0,
            maximumPossibleForce: 0,
            altitudeAngle: 0,
            azimuthUnitVector: .zero,
            rollAngle: 0,
            estimatedProperties: [],
            estimatedPropertiesExpectingUpdates: [],
            estimationUpdateIndex: seed as NSNumber
        )
        return TouchID(touch)
    }
/*
    @MainActor
    static func makeTouchHistories(_ histories: [Int: [TouchPoint]]) -> TouchHistoriesOnScreen {
        Dictionary(
            uniqueKeysWithValues: histories.map { seed, points in
                (makeTouchID(seed: seed), points)
            }
        )
    }
*/
}
