//
//  UITouchExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import UIKit

extension UITouch {

    /// Determines whether all fingers have been released from the screen
    static func isAllFingersReleasedFromScreen(
        event: UIEvent?
    ) -> Bool {
        guard let allTouches = event?.allTouches else { return false }
        return allTouches.allSatisfy { $0.phase == .ended || $0.phase == .cancelled }
    }

    static func getFingerTouches(event: UIEvent?) -> [UITouch] {
        var touches: [UITouch] = []
        event?.allTouches?.forEach { touch in
            guard touch.type != .pencil else { return }
            touches.append(touch)
        }
        return touches
    }
}
