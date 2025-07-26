//
//  UndoObjectProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/19.
//

import Combine
import Foundation
import MetalKit

/// An undo object for drawing
final class UndoDrawingObject: UndoObject {

    let undoTextureUUID: UUID

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        textureLayer: TextureLayerModel
    ) {
        self.undoTextureUUID = UUID()
        self.textureLayer = textureLayer
    }

    /// Copies a texture from the `undoTextureRepository` to the `textureLayerRepository` to restore a layer during an undo operation
    func updateTextureLayerRepositoryIfNeeded(
        _ textureLayerRepository: TextureLayerRepository,
        using undoTextureRepository: TextureRepository
    ) -> AnyPublisher<Void, Error> {
        let textureUUID = textureLayer.id
        return undoTextureRepository
            .copyTexture(uuid: undoTextureUUID)
            .flatMap { result in
                Future<Void, Error> { promise in
                    Task {
                        do {
                            _ = try await textureLayerRepository.updateTexture(
                                texture: result.texture,
                                for: textureUUID
                            )
                            promise(.success(()))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }
            }
            .eraseToAnyPublisher()
    }
}
