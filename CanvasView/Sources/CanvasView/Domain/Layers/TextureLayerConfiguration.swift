//
//  TextureLayerConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/18.
//

import Foundation

public struct TextureLayerConfiguration {
    public let canvasState: CanvasState
    public let textureLayerRepository: TextureLayerRepository
    public let undoStack: UndoStack?

    public init(canvasState: CanvasState, textureLayerRepository: TextureLayerRepository, undoStack: UndoStack?) {
        self.canvasState = canvasState
        self.textureLayerRepository = textureLayerRepository
        self.undoStack = undoStack
    }
}
