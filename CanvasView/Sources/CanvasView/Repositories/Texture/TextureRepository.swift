//
//  TextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import MetalKit

/// A protocol that defines a repository for managing textures
@MainActor
public protocol TextureRepository: Sendable {

    /// The number of textures currently managed
    var textureNum: Int { get }

    /// IDs of the textures stored in the repository
    var textureIds: Set<UUID> { get }

    /// The size of the textures managed by this repository
    var textureSize: CGSize { get }

    /// Whether this repository has been initialized
    var isInitialized: Bool { get }

    /// Initializes the storage from the given configuration, falling back to a new texture if that fails
    func initializeStorage(
        configuration: TextureLayerArrayConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration

    /// Initializes the texture storage by loading textures from the source URL and setting the texture size
    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: TextureLayerArrayConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration

    func setTextureSize(_ size: CGSize)

    func createTexture(uuid: UUID, textureSize: CGSize) async throws

    /// Adds a texture using UUID
    @discardableResult
    func addTexture(_ texture: MTLTexture, uuid: UUID) async throws -> IdentifiedTexture

    /// Copies a texture for the given UUID
    func duplicatedTexture(uuid: UUID) async throws -> IdentifiedTexture

    /// Copies multiple textures for the given UUIDs
    func duplicatedTextures(uuids: [UUID]) async throws -> [IdentifiedTexture]

    /// Removes a texture with UUID
    @discardableResult
    func removeTexture(_ uuid: UUID) throws -> UUID

    /// Removes all managed textures
    func removeAll()

    /// Updates an existing texture for UUID
    @discardableResult
    func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture
}
