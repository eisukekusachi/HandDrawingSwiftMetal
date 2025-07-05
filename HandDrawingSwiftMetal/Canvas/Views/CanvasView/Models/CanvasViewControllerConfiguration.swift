//
//  CanvasViewControllerConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/05.
//

import Foundation

struct CanvasViewControllerConfiguration {
    let canvasState: CanvasState
    let textureLayerRepository: TextureLayerRepository
    let undoStack: UndoStack?
}
