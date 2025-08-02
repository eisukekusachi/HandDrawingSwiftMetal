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
        phase: UITouch.Phase = .cancelled,
        force: CGFloat = 0,
        maximumPossibleForce: CGFloat = 0,
        estimationUpdateIndex: NSNumber? = nil,
        timestamp: TimeInterval = 0
    ) -> TouchPoint {
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
