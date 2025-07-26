//
//  TextureRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import UIKit

class TextureRepositoryWrapper: TextureRepository {

    let repository: TextureRepository

    init(repository: TextureRepository) {
        self.repository = repository
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

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.initializeStorage(configuration: configuration)
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        repository.restoreStorage(from: sourceFolderURL, with: configuration)
    }

    func setTextureSize(_ size: CGSize) {
        repository.setTextureSize(size)
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        repository.addTexture(texture, newTextureUUID: uuid)
    }

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, any Error> {
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

    func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        try await repository.updateTexture(texture: texture, for: uuid)
    }
}
