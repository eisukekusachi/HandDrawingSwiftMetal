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

    func newTexture(_ textureSize: CGSize) async throws -> MTLTexture

    /// Adds a texture using UUID
    func addTexture(_ texture: MTLTexture, id: LayerId) async throws

    /// Copies a texture for the given UUID
    func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture

    /// Copies multiple textures for the given UUIDs
    func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture]

    /// Removes a texture with UUID
    func removeTexture(_ id: LayerId) throws

    /// Removes all managed textures
    func removeAll()

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for id: LayerId) async throws
}
