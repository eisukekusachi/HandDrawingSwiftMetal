//
//  TextureLayerRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Combine
import UIKit

class TextureLayerRepositoryWrapper: TextureLayerRepository {

    let repository: TextureLayerRepository

    init(repository: TextureLayerRepository) {
        self.repository = repository
    }

    var objectWillChangeSubject: PassthroughSubject<Void, Never> {
        repository.objectWillChangeSubject
    }

    var textureNum: Int {
        repository.textureNum
    }

    /// IDs of the textures stored in the repository
    var textureIds: Set<UUID> {
        repository.textureIds
    }

    var textureSize: CGSize {
        repository.textureSize
    }

    var isInitialized: Bool {
        repository.isInitialized
    }

    func setTextureSize(_ size: CGSize) {
        repository.setTextureSize(size)
    }

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.initializeStorage(configuration: configuration)
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.restoreStorage(from: sourceFolderURL, with: configuration)
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        repository.thumbnail(uuid)
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        repository.addTexture(texture, newTextureUUID: uuid)
    }

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        repository.createTexture(uuid: uuid, textureSize: textureSize)
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

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }
}
