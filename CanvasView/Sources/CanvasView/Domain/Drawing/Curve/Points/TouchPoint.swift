//
//  TouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

@MainActor
public struct TouchPoint: Equatable {

    let location: CGPoint
    let phase: UITouch.Phase
    let force: CGFloat
    let maximumPossibleForce: CGFloat
    /// Index for identifying the estimated value
    let estimationUpdateIndex: NSNumber?

    let timestamp: TimeInterval

    public init(
        location: CGPoint,
        phase: UITouch.Phase,
        force: CGFloat,
        maximumPossibleForce: CGFloat,
        estimationUpdateIndex: NSNumber? = nil,
        timestamp: TimeInterval
    ) {
        self.location = location
        self.phase = phase
        self.force = force
        self.maximumPossibleForce = maximumPossibleForce
        self.estimationUpdateIndex = estimationUpdateIndex
        self.timestamp = timestamp
    }
}

public extension TouchPoint {

    @MainActor
    init(
        touch: UITouch,
        view: UIView
    ) {
        self.location = touch.preciseLocation(in: view)
        self.phase = touch.phase
        self.force = touch.force
        self.maximumPossibleForce = touch.maximumPossibleForce
        self.estimationUpdateIndex = touch.estimationUpdateIndex
        self.timestamp = touch.timestamp
    }

    @MainActor
    init(
        location: CGPoint,
        touch: TouchPoint
    ) {
        self.location = location
        self.phase = touch.phase
        self.force = touch.force
        self.maximumPossibleForce = touch.maximumPossibleForce
        self.estimationUpdateIndex = touch.estimationUpdateIndex
        self.timestamp = touch.timestamp
    }
}

extension Array where Element == TouchPoint {

    var lastTouchPhase: UITouch.Phase {
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
