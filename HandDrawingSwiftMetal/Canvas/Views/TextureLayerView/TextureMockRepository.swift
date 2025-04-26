//
//  TextureMockRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

import Combine
import UIKit
import Metal

final class TextureMockRepository: TextureRepository {

    var initializeCanvasAfterCreatingNewTexturePublisher: AnyPublisher<CGSize, Never> {
        initializeCanvasAfterCreatingNewTextureSubject.eraseToAnyPublisher()
    }
    var restoreCanvasFromModelPublisher: AnyPublisher<CanvasModel, Never> {
        restoreCanvasFromModelSubject.eraseToAnyPublisher()
    }

    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> {
        updateCanvasAfterTextureLayerUpdatesSubject.eraseToAnyPublisher()
    }
    var updateCanvasPublisher: AnyPublisher<Void, Never> {
        updateCanvasSubject.eraseToAnyPublisher()
    }

    /// Emit `UUID` when the thumbnail is updated
    var thumbnailWillChangePublisher: AnyPublisher<UUID, Never> {
        thumbnailWillChangeSubject.eraseToAnyPublisher()
    }

    private let initializeCanvasAfterCreatingNewTextureSubject = PassthroughSubject<CGSize, Never>()

    private let restoreCanvasFromModelSubject = PassthroughSubject<CanvasModel, Never>()

    private let updateCanvasAfterTextureLayerUpdatesSubject = PassthroughSubject<Void, Never>()

    private let updateCanvasSubject = PassthroughSubject<Void, Never>()

    private let thumbnailWillChangeSubject: PassthroughSubject<UUID, Never> = .init()

    var textureNum: Int = 0

    func resolveCanvasView(from model: CanvasModel, drawableSize: CGSize) {}

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, any Error> {
        Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize) {
        
    }

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<(any MTLTexture)?, any Error> {
        Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        let result = uuids.reduce(into: [UUID: MTLTexture?]()) { $0[$1] = nil }
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        Just(uuid)
            .eraseToAnyPublisher()
    }

    func removeAll() {}

    func setThumbnail(texture: (any MTLTexture)?, for uuid: UUID) {}

    func setAllThumbnails() {}

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateCanvasAfterTextureLayerUpdates() {
        updateCanvasAfterTextureLayerUpdatesSubject.send()
    }

    func updateCanvas() {
        updateCanvasSubject.send()
    }

}
