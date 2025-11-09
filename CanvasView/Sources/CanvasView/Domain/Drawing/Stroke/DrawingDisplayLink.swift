//
//  DrawingDisplayLink.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import UIKit
import Combine

/// A class that manages the displayLink for realtime drawing
public final class DrawingDisplayLink {

    // Requesting to update the canvas emits `Void`
    public var updatePublisher: AnyPublisher<Void, Never> {
        updateSubject.eraseToAnyPublisher()
    }
    private let updateSubject = PassthroughSubject<Void, Never>()

    public var displayLink: CADisplayLink?

    public init() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateCanvasWhileDrawing))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    public func run(_ running: Bool) {
        if running {
            displayLink?.isPaused = false
        } else {
            displayLink?.isPaused = true

            // Since the touchEnded process remains,
            // `updateCanvasWhileDrawing()` is executed once to handle the final update.
            updateCanvasWhileDrawing()
        }
    }

    public func stop() {
        displayLink?.isPaused = true
    }
}

extension DrawingDisplayLink {

    @objc private func updateCanvasWhileDrawing() {
        updateSubject.send(())
    }
}
