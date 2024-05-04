//
//  ExportCanvasData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import MetalKit

struct ExportCanvasData {
    let canvasTexture: MTLTexture
    let layerManager: LayerManager
    let drawingTool: DrawingToolModel
}
