//
//  Utils.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/06/26.
//

import UIKit
class Utils {
    class func getTouchPointWithPressure(touch: UITouch?, view: UIView) -> (CGPoint, CGFloat)? {
        guard let touch = touch else { return nil }
        var force: CGFloat = 1.0
        if touch.maximumPossibleForce != 0.0 {
            let amplifier: CGFloat = 4.0
            let offset: CGFloat = 0.1
            let t = max(0.0, min((touch.force / touch.maximumPossibleForce) * amplifier - offset, 1.0))
            force = t * t * (3 - 2 * t)
        }
        return (touch.location(in: view), force)
    }
}
