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
        guard let selectedTexture = drawingTool.layerManager.selectedTexture else { return }

        drawingTool.layerManager.drawingLayer?.drawOnDrawingTexture(
            with: iterator,
            matrix: matrix,
            parameters: drawingTool,
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
            if let selectedLayer = drawingTool.layerManager.selectedLayer {
                drawingTool.layerManager.updateThumbnail(selectedLayer)
            }
        }
    }
}
