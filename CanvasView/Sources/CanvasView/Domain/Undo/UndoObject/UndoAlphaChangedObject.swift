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

    public let textureLayer: TextureLayerItem

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layer: TextureLayerItem,
        withNewAlpha alpha: Int
    ) {
        self.textureLayer = .init(
            id: layer.id,
            title: layer.title,
            alpha: alpha,
            isVisible: layer.isVisible
        )
    }

    public func performTextureOperation(
        textureRepository: TextureRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        // Do nothing
    }
}
