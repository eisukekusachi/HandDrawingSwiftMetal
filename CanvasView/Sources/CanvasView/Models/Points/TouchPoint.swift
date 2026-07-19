//
//  TouchPoint.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

/// A `Sendable` snapshot that captures the state of a single `UITouch`
/// https://developer.apple.com/documentation/uikit/uitouch
struct TouchPoint: Equatable, Sendable {

    /// The current location of the touch in the coordinate system
    let location: CGPoint

    /// The previous location of the touch in the coordinate system
    let previousLocation: CGPoint

    /// The radius (in points) of the touch
    let majorRadius: CGFloat

    /// The tolerance (in points) of the touch’s radius
    let majorRadiusTolerance: CGFloat

    /// A precise location for the touch, when available
    let preciseLocation: CGPoint

    /// A precise previous location for the touch, when available
    let precisePreviousLocation: CGPoint

    /// The number of times the finger was tapped for this given touch
    let tapCount: Int

    /// The time when the touch occurred or when it was last mutated
    let timestamp: TimeInterval

    /// The type of touch received
    let type: UITouch.TouchType

    /// The phase of the touch
    let phase: TouchPhase

    /// The force of the touch, where a value of 1.0 represents the force of an average touch (predetermined by the system, not user-specific)
    let force: CGFloat

    /// The maximum possible force for a touch
    let maximumPossibleForce: CGFloat

    /// The altitude (in radians) of the stylus
    let altitudeAngle: CGFloat

    /// A unit vector that points in the direction of the azimuth of the stylus
    let azimuthUnitVector: CGVector

    /// A value that represents the current barrel-roll angle of Apple Pencil
    let rollAngle: CGFloat

    /// A set of touch properties whose values contain only estimates
    let estimatedProperties: UITouch.Properties

    /// The set of touch properties for which updated values are expected in the future
    let estimatedPropertiesExpectingUpdates: UITouch.Properties

    /// An index number that lets you correlate an updated touch with the original touch
    let estimationUpdateIndex: NSNumber?
}

extension TouchPoint {

    @MainActor
    init(
        touch: UITouch,
        view: UIView
    ) {
        let rollAngle: CGFloat
        if #available(iOS 17.5, *) {
            rollAngle = touch.rollAngle
        } else {
            rollAngle = 0
        }

        self.init(
            location: touch.location(in: view),
            previousLocation: touch.previousLocation(in: view),
            majorRadius: touch.majorRadius,
            majorRadiusTolerance: touch.majorRadiusTolerance,
            preciseLocation: touch.preciseLocation(in: view),
            precisePreviousLocation: touch.precisePreviousLocation(in: view),
            tapCount: touch.tapCount,
            timestamp: touch.timestamp,
            type: touch.type,
            phase: .init(touch.phase),
            force: touch.force,
            maximumPossibleForce: touch.maximumPossibleForce,
            altitudeAngle: touch.altitudeAngle,
            azimuthUnitVector: touch.azimuthUnitVector(in: view),
            rollAngle: rollAngle,
            estimatedProperties: touch.estimatedProperties,
            estimatedPropertiesExpectingUpdates: touch.estimatedPropertiesExpectingUpdates,
            estimationUpdateIndex: touch.estimationUpdateIndex
        )
    }
}

extension Array where Element == TouchPoint {
    var currentTouchPhase: TouchPhase {
        if self.last?.phase == .cancelled {
            .cancelled
        } else if self.last?.phase == .ended {
            .ended
        } else if self.first?.phase == .began {
            .began
        } else {
            .moved
        }
    }
}
