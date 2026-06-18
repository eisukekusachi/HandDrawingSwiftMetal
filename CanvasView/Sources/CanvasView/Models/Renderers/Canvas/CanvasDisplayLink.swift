//
//  CanvasDisplayLink.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import Combine
import UIKit

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

    public func run(_ phase: StrokeLifecycle) {
        switch phase {
        case .drawing:
            displayLink?.isPaused = false

        case .finalizing:
            displayLink?.isPaused = true

        case .idle:
            if displayLink?.isPaused == false {
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
}
