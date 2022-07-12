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
            let amplifier: CGFloat = 3.0
            let t = min((touch.force / touch.maximumPossibleForce) * amplifier, 1.0)
            force = t * t * (3 - 2 * t)
        }
        return (touch.location(in: view), force)
    }
}
