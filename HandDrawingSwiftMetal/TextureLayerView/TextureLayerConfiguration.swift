//
//  TextureLayerConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/18.
//

import Foundation

struct TextureLayerConfiguration {
    let canvasState: CanvasState
    let textureLayerRepository: TextureLayerRepository
    let undoStack: UndoStack?
}
