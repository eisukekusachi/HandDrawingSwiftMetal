//
//  DrawingDisplayLink.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import UIKit
import Combine

/// A class that manages the displayLink for realtime drawing
final class DrawingDisplayLink {

    // Requesting to draw a curve on the canvas emits `Void`
    var updatePublisher: AnyPublisher<Void, Never> {
        updateSubject.eraseToAnyPublisher()
    }

    private let updateSubject = PassthroughSubject<Void, Never>()

    private(set) var displayLink: CADisplayLink?

    init() {
        setupDisplayLink()
    }

    func run(_ running: Bool) {
        if running {
            displayLink?.isPaused = false
        } else {
            displayLink?.isPaused = true

            // When stopping the displayLink upon finger release,
            // the rendering process does not complete, so `updateCanvasWhileDrawing()` is executed once.
            updateCanvasWhileDrawing()
        }
    }
}

extension DrawingDisplayLink {
    private func setupDisplayLink() {
        // Configure the display link for drawing
        displayLink = CADisplayLink(target: self, selector: #selector(updateCanvasWhileDrawing))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    @objc private func updateCanvasWhileDrawing() {
        updateSubject.send(())
    }
}
