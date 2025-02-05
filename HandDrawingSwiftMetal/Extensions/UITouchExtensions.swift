//
//  UITouchExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import UIKit

extension UITouch {

    static func getFingerTouches(event: UIEvent?) -> [UITouch] {
        var touches: [UITouch] = []
        event?.allTouches?.forEach { touch in
            guard touch.type != .pencil else { return }
            touches.append(touch)
        }
        return touches
    }

    static func isAllFingersReleasedFromScreen(
        touches: Set<UITouch>,
        with event: UIEvent?
    ) -> Bool {
        touches.count == event?.allTouches?.count &&
        touches.contains { $0.phase == .ended || $0.phase == .cancelled }
    }

}
