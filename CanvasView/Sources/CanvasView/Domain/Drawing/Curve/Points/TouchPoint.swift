//
//  TouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

/// A `Sendable` snapshot that captures the state of a single `UITouch`
public struct TouchPoint: Equatable, Sendable {

    // MARK: - Touch Basics

    public let location: CGPoint

    public let previousLocation: CGPoint

    public let preciseLocation: CGPoint

    public let precisePreviousLocation: CGPoint

    /// The current phase of the touch
    public let phase: UITouch.Phase

    /// The time at which the touch event occurred, relative to system uptime
    public let timestamp: TimeInterval

    /// The number of taps associated with the touch
    public let tapCount: Int

    /// The general type of input that generated the touch, such as direct or pencil
    public let type: UITouch.TouchType

    // MARK: - Force and Pressure

    /// The force of the touch, where `1.0` represents the average touch pressure
    public let force: CGFloat

    /// The maximum possible force value that can be reported by the device
    public let maximumPossibleForce: CGFloat

    // MARK: - Touch Estimation

    /// The index used to identify estimated touch properties, if available
    public let estimationUpdateIndex: NSNumber?

    /// The currently estimated properties for this touch
    public let estimatedProperties: UITouch.Properties

    /// The properties expected to receive future updates
    public let estimatedPropertiesExpectingUpdates: UITouch.Properties

    // MARK: - Size and Shape

    /// The radius (in points) of the touch area
    public let majorRadius: CGFloat

    /// The tolerance (± points) for the reported `majorRadius`
    public let majorRadiusTolerance: CGFloat

    // MARK: - Orientation

    /// The altitude angle of the touch, in radians
    public let altitudeAngle: CGFloat

    /// The roll angle of the touch, in radians
    public let rollAngle: CGFloat
}

public extension TouchPoint {

    @MainActor
    init(
        touch: UITouch,
        view: UIView
    ) {
        self.location = touch.location(in: view)

        self.previousLocation = touch.previousLocation(in: view)

        self.preciseLocation = touch.preciseLocation(in: view)

        self.precisePreviousLocation = touch.precisePreviousLocation(in: view)

        self.phase = touch.phase

        self.timestamp = touch.timestamp

        self.tapCount = touch.tapCount

        self.type = touch.type

        self.force = touch.force

        self.maximumPossibleForce = touch.maximumPossibleForce

        self.estimationUpdateIndex = touch.estimationUpdateIndex

        self.estimatedProperties = touch.estimatedProperties

        self.estimatedPropertiesExpectingUpdates = touch.estimatedPropertiesExpectingUpdates

        self.majorRadius = touch.majorRadius

        self.majorRadiusTolerance = touch.majorRadiusTolerance

        self.altitudeAngle = touch.altitudeAngle

        if #available(iOS 17.5, *) { self.rollAngle = touch.rollAngle } else { self.rollAngle = 0 }
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
