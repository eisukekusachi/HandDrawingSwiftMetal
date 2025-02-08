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
    var requestUpdateCanvasWithDrawingPublisher: AnyPublisher<Void, Never> {
        requestUpdateCanvasWithDrawingSubject.eraseToAnyPublisher()
    }

    private let requestUpdateCanvasWithDrawingSubject = PassthroughSubject<Void, Never>()

    private(set) var displayLink: CADisplayLink?

    init() {
        setupDisplayLink()
    }

    func updateCanvasWithDrawing(
        isCurrentlyDrawing: Bool
    ) {
        if isCurrentlyDrawing {
            displayLink?.isPaused = false
        } else {
            displayLink?.isPaused = true

            // When stopping the displayLink upon finger release,
            // the rendering process does not complete, so `updateCanvasWhileDrawing()` is executed once.
            updateCanvasWhileDrawing()
        }
    }

}

extension CanvasDrawingDisplayLink {
    private func setupDisplayLink() {
        // Configure the display link for drawing
        displayLink = CADisplayLink(target: self, selector: #selector(updateCanvasWhileDrawing))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    @objc private func updateCanvasWhileDrawing() {
        requestUpdateCanvasWithDrawingSubject.send(())
    }

}
