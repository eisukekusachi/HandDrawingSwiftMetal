//
//  UITouchExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/08/07.
//

import UIKit
extension UITouch {
    func getPointAndPressure(_ view: UIView) -> (CGPoint, CGFloat)? {
        var force: CGFloat = 1.0
        if self.maximumPossibleForce != 0.0 {
            force = self.force / self.maximumPossibleForce
        }
        return (self.location(in: view), force)
    }
}
