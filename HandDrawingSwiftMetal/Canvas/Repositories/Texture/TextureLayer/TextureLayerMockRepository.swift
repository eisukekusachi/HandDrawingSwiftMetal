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

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        objectWillChangeSubject.eraseToAnyPublisher()
    }
    private let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    var textureNum: Int = 0

    var textureSize: CGSize = .zero

    var isInitialized: Bool = false

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
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
