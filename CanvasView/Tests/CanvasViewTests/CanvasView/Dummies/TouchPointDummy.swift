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
        location: CGPoint = .zero,
        previousLocation: CGPoint = .zero,
        majorRadius: CGFloat = 0,
        majorRadiusTolerance: CGFloat = 0,
        preciseLocation: CGPoint = .zero,
        precisePreviousLocation: CGPoint = .zero,
        tapCount: Int = 0,
        timestamp: TimeInterval = .zero,
        type: UITouch.TouchType = .direct,
        phase: UITouch.Phase = .cancelled,
        force: CGFloat = 0,
        maximumPossibleForce: CGFloat = 0,
        altitudeAngle: CGFloat = 0,
        azimuthUnitVector: CGVector = .zero,
        rollAngle: CGFloat = 0,
        estimatedProperties: UITouch.Properties = .force,
        estimatedPropertiesExpectingUpdates: UITouch.Properties = .force,
        estimationUpdateIndex: NSNumber? = 0
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
