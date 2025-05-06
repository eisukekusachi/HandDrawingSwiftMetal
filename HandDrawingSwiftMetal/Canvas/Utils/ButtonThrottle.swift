//
//  ButtonThrottle.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/06.
//

import SwiftUI

final class ButtonThrottle {
    private var isLocked = [String: Bool]()
    private let queue = DispatchQueue(label: "com.hand-drawing-swift-metal.ButtonThrottleQueue")

    func throttle(
        id: String = "default",
        delay: TimeInterval = 0.8,
        action: @escaping () -> Void
    ) {
        queue.async {
            if self.isLocked[id] == true {
                return
            }

            self.isLocked[id] = true

            DispatchQueue.main.async {
                action()
            }

            self.queue.asyncAfter(deadline: .now() + delay) {
                self.isLocked[id] = false
            }
        }
    }
}
