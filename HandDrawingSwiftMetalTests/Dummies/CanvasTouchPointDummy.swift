//
//  CanvasTouchPointDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import UIKit
@testable import HandDrawingSwiftMetal

extension CanvasTouchPoint {

    static func generate(
        location: CGPoint = .zero,
        phase: UITouch.Phase = .cancelled,
        force: CGFloat = 0,
        maximumPossibleForce: CGFloat = 0,
        estimationUpdateIndex: NSNumber? = nil,
        timestamp: TimeInterval = 0
    ) -> CanvasTouchPoint {
        .init(
            location: location,
            phase: phase,
            force: force,
            maximumPossibleForce: maximumPossibleForce,
            estimationUpdateIndex: estimationUpdateIndex,
            timestamp: timestamp
        )
    }

}
