//
//  TextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Foundation
import MetalKit

/// A protocol that defines a repository for managing textures
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

    /// Initializes the texture storage and setting the texture size
    func initializeStorage(from configuration: CanvasConfiguration)

    /// Initializes the texture storage with a new texture and setting the texture size
    func initializeStorageWithNewTexture(_ textureSize: CGSize)

    /// Initializes the texture storage by loading textures from the source URL and setting the texture size
    func initializeStorage(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error>

    func setTextureSize(_ size: CGSize)

    /// Adds a texture using UUID
    func addTexture(_ texture: MTLTexture?, using uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, Error>

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, Error>

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) -> AnyPublisher<[TextureRepositoryEntity], Error>

    /// Removes all managed textures
    func removeAll()

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error>

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
    case fileAlreadyExists
    case fileNotFound
}
