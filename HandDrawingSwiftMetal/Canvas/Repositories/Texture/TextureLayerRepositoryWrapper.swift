//
//  TextureLayerRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Combine
import UIKit

class TextureLayerRepositoryWrapper: ObservableObject, TextureWithThumbnailRepository {

    let repository: TextureWithThumbnailRepository

    init(repository: TextureWithThumbnailRepository) {
        self.repository = repository
    }

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.storageInitializationWithNewTexturePublisher
    }
    var storageInitializationCompletedPublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.storageInitializationCompletedPublisher
    }

    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> {
        repository.thumbnailUpdateRequestedPublisher
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

    func initializeStorage(from configuration: CanvasConfiguration) {
        repository.initializeStorage(from: configuration)
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {
        repository.initializeStorageWithNewTexture(textureSize)
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        repository.getThumbnail(uuid)
    }

    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<(any MTLTexture)?, any Error> {
        repository.getTexture(uuid: uuid, textureSize: textureSize)
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        repository.getTextures(uuids: uuids, textureSize: textureSize)
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        repository.removeTexture(uuid)
    }

    func removeAll() {
        repository.removeAll()
    }

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }

    func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, any Error> {
        repository.updateAllTextures(uuids: uuids, textureSize: textureSize, from: sourceURL)
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        repository.updateAllThumbnails(textureSize: textureSize)
    }

}
