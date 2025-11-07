//
//  TouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

/// A `Sendable` snapshot that captures the state of a single `UITouch`
/// https://developer.apple.com/documentation/uikit/uitouch
public struct TouchPoint: Equatable, Sendable {

    /// The current location of the touch in the coordinate system
    public let location: CGPoint

    /// The previous location of the touch in the coordinate system
    public let previousLocation: CGPoint

    /// The radius (in points) of the touch
    public let majorRadius: CGFloat

    /// The tolerance (in points) of the touch’s radius
    public let majorRadiusTolerance: CGFloat

    /// A precise location for the touch, when available
    public let preciseLocation: CGPoint

    /// A precise previous location for the touch, when available
    public let precisePreviousLocation: CGPoint

    /// The number of times the finger was tapped for this given touch
    public let tapCount: Int

    /// The time when the touch occurred or when it was last mutated
    public let timestamp: TimeInterval

    /// The type of touch received
    public let type: UITouch.TouchType

    /// The phase of the touch
    public let phase: UITouch.Phase

    /// The force of the touch, where a value of 1.0 represents the force of an average touch (predetermined by the system, not user-specific)
    public let force: CGFloat

    /// The maximum possible force for a touch
    public let maximumPossibleForce: CGFloat

    /// The altitude (in radians) of the stylus
    public let altitudeAngle: CGFloat

    /// A unit vector that points in the direction of the azimuth of the stylus
    public let azimuthUnitVector: CGVector

    /// A value that represents the current barrel-roll angle of Apple Pencil
    public let rollAngle: CGFloat

    /// A set of touch properties whose values contain only estimates
    public let estimatedProperties: UITouch.Properties

    /// The set of touch properties for which updated values are expected in the future
    public let estimatedPropertiesExpectingUpdates: UITouch.Properties

    /// An index number that lets you correlate an updated touch with the original touch
    public let estimationUpdateIndex: NSNumber?

    public init(
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
    ) {
        self.location = location
        self.previousLocation = previousLocation
        self.majorRadius = majorRadius
        self.majorRadiusTolerance = majorRadiusTolerance
        self.preciseLocation = preciseLocation
        self.precisePreviousLocation = precisePreviousLocation
        self.tapCount = tapCount
        self.timestamp = timestamp
        self.type = type
        self.phase = phase
        self.force = force
        self.maximumPossibleForce = maximumPossibleForce
        self.altitudeAngle = altitudeAngle
        self.azimuthUnitVector = azimuthUnitVector
        self.rollAngle = rollAngle
        self.estimatedProperties = estimatedProperties
        self.estimatedPropertiesExpectingUpdates = estimatedPropertiesExpectingUpdates
        self.estimationUpdateIndex = estimationUpdateIndex
    }
}

extension TouchPoint {

    @MainActor
    public init(
        touch: UITouch,
        view: UIView
    ) {
        self.location = touch.location(in: view)

        self.previousLocation = touch.previousLocation(in: view)

        self.majorRadius = touch.majorRadius

        self.majorRadiusTolerance = touch.majorRadiusTolerance

        self.preciseLocation = touch.preciseLocation(in: view)

        self.precisePreviousLocation = touch.precisePreviousLocation(in: view)

        self.tapCount = touch.tapCount

        self.timestamp = touch.timestamp

        self.type = touch.type

        self.phase = touch.phase

        self.force = touch.force

        self.maximumPossibleForce = touch.maximumPossibleForce

        self.altitudeAngle = touch.altitudeAngle

        self.azimuthUnitVector = touch.azimuthUnitVector(in: view)

        if #available(iOS 17.5, *) { self.rollAngle = touch.rollAngle } else { self.rollAngle = 0 }

        self.estimatedProperties = touch.estimatedProperties

        self.estimatedPropertiesExpectingUpdates = touch.estimatedPropertiesExpectingUpdates

        self.estimationUpdateIndex = touch.estimationUpdateIndex
    }
}

extension Array where Element == TouchPoint {
    var currentTouchPhase: UITouch.Phase {
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
