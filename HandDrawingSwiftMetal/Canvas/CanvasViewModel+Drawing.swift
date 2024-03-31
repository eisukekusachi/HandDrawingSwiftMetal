//
//  CanvasViewModel+Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/04.
//

import MetalKit

// MARK: Drawing
extension CanvasViewModel {
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>,
                              matrix: CGAffineTransform,
                              touchPhase: UITouch.Phase,
                              _ commandBuffer: MTLCommandBuffer) {
        guard let selectedTexture = parameters.layerManager.selectedTexture else { return }

        parameters.layerManager.drawingLayer?.drawOnDrawingTexture(
            with: iterator,
            matrix: matrix,
            parameters: parameters,
            on: selectedTexture,
            touchPhase,
            commandBuffer)

        if touchPhase == .ended {
            updateThumbnail()
        }
    }

    private func updateThumbnail() {
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 1 * 1000 * 1000)
            if let selectedLayer = parameters.layerManager.selectedLayer {
                parameters.layerManager.updateThumbnail(selectedLayer)
            }
        }
    }
}
