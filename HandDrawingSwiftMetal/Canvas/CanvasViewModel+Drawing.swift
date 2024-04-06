//
//  CanvasViewModel+Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/04.
//

import MetalKit

// MARK: Drawing
extension CanvasViewModel {

    private func updateThumbnail() {
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 1 * 1000 * 1000)
            if let selectedLayer = drawingTool.layerManager.selectedLayer {
                drawingTool.layerManager.updateThumbnail(selectedLayer)
            }
        }
    }
}
