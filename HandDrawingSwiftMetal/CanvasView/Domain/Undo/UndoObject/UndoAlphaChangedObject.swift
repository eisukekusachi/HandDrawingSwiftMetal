//
//  UndoAlphaChangedObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/28.
//

import Combine
import Foundation
import MetalKit

/// An undo object for updating a texture layer
public final class UndoAlphaChangedObject: UndoObject {

    /// Not used
    public let undoTextureUUID: UUID = UUID()

    public let textureLayer: TextureLayerModel

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    public init(
        alpha: Int,
        textureLayer: TextureLayerModel
    ) {
        self.textureLayer = .init(model: textureLayer, alpha: alpha)
    }

    public init(
        _ object: UndoAlphaChangedObject,
        withNewAlpha newAlpha: Int
    ) {
        let textureLayer = object.textureLayer
        self.textureLayer = .init(model: textureLayer, alpha: newAlpha)
    }

    public func performUndo(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        // Do nothing
    }
}
