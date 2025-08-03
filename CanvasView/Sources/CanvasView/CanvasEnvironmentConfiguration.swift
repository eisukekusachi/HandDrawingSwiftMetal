//
//  CanvasEnvironmentConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/28.
//

import UIKit

public enum StorageType: Sendable {
    case disk
    case memory
}

public struct CanvasEnvironmentConfiguration: Sendable {
    /// The background color of the canvas
    let backgroundColor: UIColor

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    let baseBackgroundColor: UIColor

    /// For the canvas’s textureRepository type: if `.disk` is selected, Core Data is automatically created and textures are persisted
    let textureRepositoryType: StorageType

    /// For the repository type used to store undo textures. even if `.disk` is selected, it only uses disk storage temporarily and textures are not persisted.
    let undoTextureRepositoryType: StorageType?

    public init(
        backgroundColor: UIColor = .white,
        baseBackgroundColor: UIColor = UIColor(230, 230, 230),
        textureRepositoryType: StorageType = .disk,
        undoTextureRepositoryType: StorageType? = .disk
    ) {
        self.backgroundColor = backgroundColor
        self.baseBackgroundColor = baseBackgroundColor
        self.textureRepositoryType = textureRepositoryType
        self.undoTextureRepositoryType = undoTextureRepositoryType
    }
}
