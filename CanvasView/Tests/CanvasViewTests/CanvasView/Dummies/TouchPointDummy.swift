//
//  TouchPointDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import CanvasView
import UIKit

public extension TouchPoint {

    static func generate(
        location: CGPoint,
        previousLocation: CGPoint,
        majorRadius: CGFloat,
        majorRadiusTolerance: CGFloat,
        preciseLocation: CGPoint,
        precisePreviousLocation: CGPoint,
        tapCount: Int,
        timestamp: TimeInterval,
        type: UITouch.TouchType,
        phase: UITouch.Phase,
        force: CGFloat,
        maximumPossibleForce: CGFloat,
        altitudeAngle: CGFloat,
        azimuthUnitVector: CGVector,
        rollAngle: CGFloat,
        estimatedProperties: UITouch.Properties,
        estimatedPropertiesExpectingUpdates: UITouch.Properties,
        estimationUpdateIndex: NSNumber?
    ) -> Self {
        .init(
            location: location,
            previousLocation: previousLocation,
            majorRadius: majorRadius,
            majorRadiusTolerance: majorRadiusTolerance,
            preciseLocation: preciseLocation,
            precisePreviousLocation: precisePreviousLocation,
            tapCount: tapCount,
            timestamp: timestamp,
            type: type,
            phase: phase,
            force: force,
            maximumPossibleForce: maximumPossibleForce,
            altitudeAngle: altitudeAngle,
            azimuthUnitVector: azimuthUnitVector,
            rollAngle: rollAngle,
            estimatedProperties: estimatedProperties,
            estimatedPropertiesExpectingUpdates: estimatedPropertiesExpectingUpdates,
            estimationUpdateIndex: estimationUpdateIndex
        )
    }
}
