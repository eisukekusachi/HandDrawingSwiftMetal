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

}
