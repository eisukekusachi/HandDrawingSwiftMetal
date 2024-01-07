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
                              touchState: TouchState,
                              _ commandBuffer: MTLCommandBuffer) {
        guard let selectedTexture = layerManager.selectedTexture else { return }

        drawing?.drawOnDrawingTexture(with: iterator,
                                      matrix: matrix,
                                      on: selectedTexture,
                                      touchState,
                                      commandBuffer)
        if touchState == .ended {
            updateThumbnail()
        }
    }
    func mergeAllLayers(backgroundColor: (Int, Int, Int),
                        to dstTexture: MTLTexture,
                        _ commandBuffer: MTLCommandBuffer) {
        guard let selectedTexture = layerManager.selectedTexture,
              let selectedTextures = drawing?.getDrawingTextures(selectedTexture) else { return }
        let selectedAlpha = layerManager.selectedLayerAlpha

        layerManager.mergeAllTextures(selectedTextures: selectedTextures.compactMap { $0 },
                                      selectedAlpha: selectedAlpha,
                                      backgroundColor: backgroundColor,
                                      to: dstTexture,
                                      commandBuffer)
    }

    private func updateThumbnail() {
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 1 * 1000 * 1000)
            if let selectedLayer = layerManager.selectedLayer {
                layerManager.updateThumbnail(selectedLayer)
            }
        }
    }
}
