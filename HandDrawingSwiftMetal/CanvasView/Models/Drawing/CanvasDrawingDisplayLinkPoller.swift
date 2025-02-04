//
//  CanvasDrawingDisplayLinkPoller.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/02/04.
//

import UIKit
import Combine

final class CanvasDrawingDisplayLinkPoller {

    var requestDrawingOnCanvasPublisher: AnyPublisher<(MTLTexture, MTLCommandBuffer), Never> {
        requestDrawingOnCanvasSubject.eraseToAnyPublisher()
    }

    private let requestDrawingOnCanvasSubject = PassthroughSubject<(MTLTexture, MTLCommandBuffer), Never>()

    private var displayLink: CADisplayLink?

    private var texture: MTLTexture?

    private var canvasView: CanvasViewProtocol?

    init() {
        setupDisplayLink()
    }

    func onViewDidLoad(canvasView: CanvasViewProtocol) {
        self.canvasView = canvasView
    }

    func updateDrawingTextureWithPolling(
        isCurrentlyDrawing: Bool,
        texture: MTLTexture?
    ) {
        self.texture = texture

        if isCurrentlyDrawing {
            displayLink?.isPaused = false
        } else {
            displayLink?.isPaused = true
            updateDrawingTextureWhileDrawing()
        }
    }

}

extension CanvasDrawingDisplayLinkPoller {
    private func setupDisplayLink() {
        // Configure the display link for rendering
        displayLink = CADisplayLink(target: self, selector: #selector(updateDrawingTextureWhileDrawing))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

    @objc private func updateDrawingTextureWhileDrawing() {
        guard
            let texture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        requestDrawingOnCanvasSubject.send((texture, commandBuffer))
    }

}
