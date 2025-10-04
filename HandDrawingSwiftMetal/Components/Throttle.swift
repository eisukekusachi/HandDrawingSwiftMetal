//
//  Throttle.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/10/04.
//

import UIKit

/// Executes the action immediately on the first tap, then ignores subsequent taps until the given delay has elapsed
final class Throttle {
    private let delay: TimeInterval
    private var isLocked = false

    init(delay: TimeInterval = 0.5) {
        self.delay = delay
    }

    func run(_ button: UIButton, _ action: () -> Void) {
        run([button], action)
    }

    func run(_ buttons: [UIButton], _ action: () -> Void) {
        if isLocked { return }

        // Lock and disable touch (preserve appearance)
        isLocked = true
        buttons.forEach { $0.isUserInteractionEnabled = false }

        action()

        // Re-enable after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            buttons.forEach { $0.isUserInteractionEnabled = true }
            self?.isLocked = false
        }
    }
}
