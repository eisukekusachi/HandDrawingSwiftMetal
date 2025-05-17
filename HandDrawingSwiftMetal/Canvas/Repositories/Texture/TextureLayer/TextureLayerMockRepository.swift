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

    func initializeStorage(from configuration: CanvasConfiguration) {}

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, any Error> {
        Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {

    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error> {
        Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[TextureRepositoryEntity], Error> {
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        Just(uuid).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeAll() {}

    func setThumbnail(texture: (any MTLTexture)?, for uuid: UUID) {}

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
