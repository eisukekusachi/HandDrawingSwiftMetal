//
//  TextureLayerConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/18.
//

import UIKit

public struct TextureLayerConfiguration {
    public let canvasState: CanvasState
    public let textureRepository: TextureRepository
    public let undoStack: UndoStack?

    public let defaultBackgroundColor: UIColor
    public let selectedBackgroundColor: UIColor

    public init(
        canvasState: CanvasState,
        textureRepository: TextureRepository,
        undoStack: UndoStack?,
        defaultBackgroundColor: UIColor = .white,
        selectedBackgroundColor: UIColor = .black
    ) {
        self.canvasState = canvasState
        self.textureRepository = textureRepository
        self.undoStack = undoStack
        self.defaultBackgroundColor = defaultBackgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
    }
}
