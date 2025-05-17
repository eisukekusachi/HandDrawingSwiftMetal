//
//  TextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Foundation
import MetalKit

/// A repository that manages textures
protocol TextureRepository {

    /// A publisher that emits to trigger initialization of the storage using `CanvasConfiguration`
    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// A publisher that emits to trigger initialization of the canvas using `CanvasConfiguration`
    var storageInitializationCompletedPublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// The number of textures currently managed
    var textureNum: Int { get }

    /// The size of the textures managed by this repository
    var textureSize: CGSize { get }

    /// Whether this repository has been initialized
    var isInitialized: Bool { get }

    /// Initializes the storage
    func initializeStorage(from configuration: CanvasConfiguration)

    /// Initializes the storage with a new texture
    func initializeStorageWithNewTexture(_ textureSize: CGSize)

    /// Gets a texture for the given UUID
    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error>

    /// Gets multiple textures for the given UUIDs
    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID: MTLTexture?], Error>

    /// Removes all managed textures
    func removeAll()

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error>

    /// Updates all textures for the given uuids using a directory URL
    func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error>

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error>

}

enum TextureRepositoryError: Error {
    case notFound
    case failedToUnwrap
    case failedToLoadTexture
    case failedToAddTexture
    case failedToUpdateTexture
    case failedToCommitCommandBuffer
    case invalidTexture
    case repositoryDeinitialized
    case repositoryUnavailable
}
