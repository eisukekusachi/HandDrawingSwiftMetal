//
//  TextureRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import UIKit

class TextureRepositoryWrapper: ObservableObject, TextureRepository {

    let repository: TextureRepository

    init(repository: TextureRepository) {
        self.repository = repository
    }

    var textureNum: Int {
        repository.textureNum
    }

    var textureSize: CGSize {
        repository.textureSize
    }

    var isInitialized: Bool {
        repository.isInitialized
    }

    func initialize(from configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, any Error> {
        repository.initialize(from: configuration)
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.resetStorage(configuration: configuration, sourceFolderURL: sourceFolderURL)
    }

    func setTextureSize(_ size: CGSize) {}

    func addTexture(_ texture: (any MTLTexture)?, using uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, any Error> {
        repository.addTexture(texture, using: uuid)
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, Error> {
        repository.copyTexture(uuid: uuid)
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[TextureRepositoryEntity], Error> {
        repository.copyTextures(uuids: uuids)
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        repository.removeTexture(uuid)
    }

    func removeAll() {
        repository.removeAll()
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }

}
