//
//  TextureLayerConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/18.
//

import Foundation

public struct TextureLayerConfiguration {
    public let canvasState: CanvasState
    public let textureRepository: TextureRepository
    public let undoStack: UndoStack?

    public init(canvasState: CanvasState, textureRepository: TextureRepository, undoStack: UndoStack?) {
        self.canvasState = canvasState
        self.textureRepository = textureRepository
        self.undoStack = undoStack
    }
}
