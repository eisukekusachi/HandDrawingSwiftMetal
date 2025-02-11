//
//  CanvasTouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

struct CanvasTouchPoint: Equatable {

    let location: CGPoint
    let phase: UITouch.Phase
    let force: CGFloat
    let maximumPossibleForce: CGFloat
    /// Index for identifying the estimated value
    var estimationUpdateIndex: NSNumber? = nil

    let timestamp: TimeInterval
}

extension CanvasTouchPoint {

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

    init(
        location: CGPoint,
        touch: CanvasTouchPoint
    ) {
        self.location = location
        self.phase = touch.phase
        self.force = touch.force
        self.maximumPossibleForce = touch.maximumPossibleForce
        self.estimationUpdateIndex = touch.estimationUpdateIndex
        self.timestamp = touch.timestamp
    }

}

extension Array where Element == CanvasTouchPoint {

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
