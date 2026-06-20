//
//  UITouchExtensions.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import UIKit

extension UITouch {
    /// Determines whether all fingers have been released from the screen
    static func isAllFingersReleasedFromScreen(
        event: UIEvent?,
        touches: Set<UITouch> = []
    ) -> Bool {
        let allTouches = event?.allTouches ?? touches
        guard !allTouches.isEmpty else { return false }
        return allTouches.allSatisfy { $0.phase == .ended || $0.phase == .cancelled }
    }

    @MainActor
    static func fingerTouchesOnScreen(
        touches: Set<UITouch>,
        from event: UIEvent?,
        on view: UIView
    ) -> TouchesOnScreen {
        (event?.allTouches ?? touches).reduce(into: TouchesOnScreen()) { touchesOnScreen, touch in
            guard touch.type != .pencil else { return }
            touchesOnScreen[TouchID(touch)] = TouchPoint(touch: touch, view: view)
        }
    }
}
