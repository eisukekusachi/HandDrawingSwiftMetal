//
//  CanvasDisplayLink.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import Combine
import UIKit

/// A `CADisplayLink` wrapper for realtime stroke rendering.
public final class CanvasDisplayLink {

    /// Emits once per frame while running, and once more when stopping after a draw session.
    public var update: AnyPublisher<Void, Never> {
        updateSubject.eraseToAnyPublisher()
    }
    private let updateSubject = PassthroughSubject<Void, Never>()

    public var displayLink: CADisplayLink?

    /// Whether the underlying `CADisplayLink` is ticking.
    public var isRunning: Bool {
        displayLink?.isPaused == false
    }

    deinit {
        displayLink?.invalidate()
    }

    public init(isPaused: Bool = true) {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFrame))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = isPaused
    }

    /// Starts or stops realtime drawing frames.
    /// Stopping after an active session emits one final update.
    public func run(_ isRunning: Bool) {
        if isRunning {
            displayLink?.isPaused = false
            return
        }

        if self.isRunning {
            updateSubject.send()
        }
        displayLink?.isPaused = true
    }
}

private extension CanvasDisplayLink {

    @objc func displayLinkFrame() {
        updateSubject.send()
    }
}
