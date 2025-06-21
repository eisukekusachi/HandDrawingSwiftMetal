//
//  TextureLayerMockRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

import Combine
import UIKit
import Metal

final class TextureLayerMockRepository: TextureLayerRepository {

    private let device = MTLCreateSystemDefaultDevice()!

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }
    var storageInitializationCompletedPublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationCompletedSubject.eraseToAnyPublisher()
    }

    /// Emit `UUID` when the thumbnail is updated
    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> {
        thumbnailUpdateRequestedSubject.eraseToAnyPublisher()
    }

    private let storageInitializationWithNewTextureSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let storageInitializationCompletedSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let thumbnailUpdateRequestedSubject: PassthroughSubject<UUID, Never> = .init()

    var textureNum: Int = 0

    var textureSize: CGSize = .zero

    var isInitialized: Bool = false

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(from configuration: CanvasConfiguration) {}

    func initializeStorage(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {

    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func addTexture(_ texture: (any MTLTexture)?, using uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, any Error> {
        return Just(.init(uuid: UUID()))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, Error> {
        return Just(.init(uuid: UUID()))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[TextureRepositoryEntity], Error> {
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        Just(uuid).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeAll() {}

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {}

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
