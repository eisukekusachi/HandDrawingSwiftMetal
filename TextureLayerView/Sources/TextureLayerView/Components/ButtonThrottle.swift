//
//  ButtonThrottle.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/11.
//

import SwiftUI

final class ButtonThrottle: @unchecked Sendable {
    private var isLocked = [String: Bool]()
    private let queue = DispatchQueue(label: "com.hand-drawing-swift-metal.ButtonThrottleQueue")

    func throttle(
        id: String = "default",
        delay: TimeInterval = 0.8,
        action: @Sendable @escaping () -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if self.isLocked[id] == true {
                return
            }

            self.isLocked[id] = true

            let actionCopy = action

            DispatchQueue.main.async {
                actionCopy()
            }

            self.queue.asyncAfter(deadline: .now() + delay) {
                self.isLocked[id] = false
            }
        }
    }
}
