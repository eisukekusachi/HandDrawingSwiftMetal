//
//  CanvasDisplayLink.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import UIKit
import Combine

/// Manages the displayLink for realtime drawing
public final class CanvasDisplayLink {

    // Requesting to update the canvas emits `Void`
    public var update: AnyPublisher<Void, Never> {
        updateSubject.eraseToAnyPublisher()
    }
    private let updateSubject = PassthroughSubject<Void, Never>()

    public var displayLink: CADisplayLink?

    deinit {
        displayLink?.invalidate()
    }

    public init(isPaused: Bool = true) {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFrame))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = isPaused
    }

    public func run(_ touchPhase: UITouch.Phase?) {
        if isCurrentlyDrawing(touchPhase) {
            displayLink?.isPaused = false
        } else {
            if displayLink?.isPaused == false {
                // Since the touchEnded process remains,
                // `updateCanvasWhileDrawing()` is executed once to handle the final update.
                updateSubject.send()
            }

            displayLink?.isPaused = true
        }
    }
}

private extension CanvasDisplayLink {

    @objc func displayLinkFrame() {
        updateSubject.send()
    }

    func isCurrentlyDrawing(_ touchPhase: UITouch.Phase?) -> Bool {
        switch touchPhase {
        case .began, .moved, .stationary: return true
        default: return false
        }
    }
}
