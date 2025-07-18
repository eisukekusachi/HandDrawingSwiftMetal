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

    /// The number of textures currently managed
    var textureNum: Int { get }

    /// IDs of the textures stored in the repository
    var textureIds: Set<UUID> { get }

    /// The size of the textures managed by this repository
    var textureSize: CGSize { get }

    /// Whether this repository has been initialized
    var isInitialized: Bool { get }

    /// Initializes the storage from the given configuration, falling back to a new texture if that fails
    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error>

    /// Initializes the texture storage by loading textures from the source URL and setting the texture size
    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error>

    func setTextureSize(_ size: CGSize)

    /// Adds a texture using UUID
    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error>

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error>

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error>

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) -> AnyPublisher<[IdentifiedTexture], Error>

    /// Removes all managed textures
    func removeAll()

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error>

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error>

}

enum TextureRepositoryError: Error {
    case failedToUnwrap
    case failedToLoadTexture
    case failedToAddTexture
    case failedToUpdateTexture
    case fileAlreadyExists
    case fileNotFound(String)
    case invalidTextureSize
    case invalidValue(String)
}
