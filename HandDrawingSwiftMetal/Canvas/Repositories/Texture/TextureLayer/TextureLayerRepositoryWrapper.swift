//
//  TextureLayerRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Combine
import UIKit

class TextureLayerRepositoryWrapper: ObservableObject, TextureLayerRepository {

    let repository: TextureLayerRepository

    init(repository: TextureLayerRepository) {
        self.repository = repository
    }

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        repository.objectWillChangePublisher
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

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.initializeStorage(configuration: configuration)
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.resetStorage(configuration: configuration, sourceFolderURL: sourceFolderURL)
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        repository.thumbnail(uuid)
    }

    func addTexture(_ texture: (any MTLTexture)?, using uuid: UUID) -> AnyPublisher<IdentifiedTexture, any Error> {
        repository.addTexture(texture, using: uuid)
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        repository.copyTexture(uuid: uuid)
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[IdentifiedTexture], Error> {
        repository.copyTextures(uuids: uuids)
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        repository.removeTexture(uuid)
    }

    func removeAll() {
        repository.removeAll()
    }

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        repository.updateAllThumbnails(textureSize: textureSize)
    }

}
