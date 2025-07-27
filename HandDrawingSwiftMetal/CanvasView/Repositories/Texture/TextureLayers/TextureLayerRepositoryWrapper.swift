//
//  TextureLayerRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Combine
import UIKit

class TextureLayerRepositoryWrapper: TextureLayerRepository, @unchecked Sendable {
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

    func initializeStorage(configuration: CanvasConfiguration) async throws -> CanvasConfiguration {
        try await repository.initializeStorage(configuration: configuration)
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) async throws {
        try await repository.restoreStorage(from: sourceFolderURL, with: configuration)
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        repository.thumbnail(uuid)
    }

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {
        try await repository.createTexture(uuid: uuid, textureSize: textureSize)
    }

    func removeAll() {
        repository.removeAll()
    }

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        try await repository.copyTexture(uuid: uuid)
    }

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) async throws -> [IdentifiedTexture] {
        try await repository.copyTextures(uuids: uuids)
    }

    /// Adds a texture using UUID
    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        try await repository.addTexture(texture, newTextureUUID: uuid)
    }

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) throws -> UUID {
        try repository.removeTexture(uuid)
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        try await repository.updateTexture(texture: texture, for: uuid)
    }
}
