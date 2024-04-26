//
//  TouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

struct TouchPoint: Equatable {

    let location: CGPoint
    let force: CGFloat
    let maximumPossibleForce: CGFloat
    let phase: UITouch.Phase
    let type: UITouch.TouchType

    init(touch: UITouch, view: UIView) {
        self.location = touch.preciseLocation(in: view)
        self.force = touch.force
        self.maximumPossibleForce = touch.maximumPossibleForce
        self.phase = touch.phase
        self.type = touch.type
    }

}
