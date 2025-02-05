//
//  CanvasDrawingDisplayLink.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import UIKit
import Combine

/// A class that manages the displayLink for drawing
final class CanvasDrawingDisplayLink {

    // Requesting to draw a line on the canvas emits `Void`
    var requestDrawingOnCanvasPublisher: AnyPublisher<Void, Never> {
        requestDrawingOnCanvasSubject.eraseToAnyPublisher()
    }

    private let requestDrawingOnCanvasSubject = PassthroughSubject<Void, Never>()

    private(set) var displayLink: CADisplayLink?

    init() {
        setupDisplayLink()
    }

    func runDisplayLink(
        isCurrentlyDrawing: Bool
    ) {
        if isCurrentlyDrawing {
            displayLink?.isPaused = false
        } else {
            displayLink?.isPaused = true

            // When stopping the displayLink upon finger release,
            // the rendering process does not complete, so `updateDrawingTextureWhileDrawing()` is executed once.
            updateDrawingTextureWhileDrawing()
        }
    }

}

extension CanvasDrawingDisplayLink {
    private func setupDisplayLink() {
        // Configure the display link for drawing
        displayLink = CADisplayLink(target: self, selector: #selector(updateDrawingTextureWhileDrawing))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    @objc private func updateDrawingTextureWhileDrawing() {
        requestDrawingOnCanvasSubject.send(())
    }

}
