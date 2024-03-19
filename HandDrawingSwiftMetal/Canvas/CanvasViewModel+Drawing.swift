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

        parameters.drawing?.drawOnDrawingTexture(with: iterator,
                                                 matrix: matrix,
                                                 parameters: parameters,
                                                 on: selectedTexture,
                                                 touchPhase,
                                                 commandBuffer)
        if touchPhase == .ended {
            updateThumbnail()
        }
    }

    func mergeAllLayers(to dstTexture: MTLTexture,
                        _ commandBuffer: MTLCommandBuffer) {
        guard let selectedTexture = parameters.layerManager.selectedTexture,
              let selectedTextures = parameters.drawing?.getDrawingTextures(selectedTexture) else { return }

        parameters.layerManager.mergeAllTextures(selectedTextures: selectedTextures.compactMap { $0 },
                                                 selectedAlpha: parameters.layerManager.selectedLayerAlpha,
                                                 backgroundColor: parameters.backgroundColorSubject.value.rgb,
                                                 to: dstTexture,
                                                 commandBuffer)
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
