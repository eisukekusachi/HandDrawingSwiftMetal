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

    /// The number of textures currently managed
    var textureNum: Int { get }

    var textureSize: CGSize { get }

    var hasTexturesBeenInitialized: Bool { get }

    /// A publisher that emits to trigger initialization of the storage using `CanvasConfiguration`
    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// A publisher that emits to trigger initialization of the canvas using `CanvasConfiguration`
    var canvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// A publisher that notifies SwiftUI about a thumbnail update for a specific layer
    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> { get }

    /// Initialized the storage
    func initializeStorage(from configuration: CanvasConfiguration)

    /// Initialized the storage with a new texture
    func initializeStorageWithNewTexture(_ textureSize: CGSize)

    /// Gets a texture for the given UUID
    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error>

    /// Gets multiple textures for the given UUIDs
    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID: MTLTexture?], Error>

    /// Retrieves the thumbnail image for UUID
    func getThumbnail(_ uuid: UUID) -> UIImage?

    /// Removes all managed textures
    func removeAll()

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error>

    /// Updates all textures for the given uuids using a directory URL
    func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error>

    /// Updates all thumbnails
    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error>

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error>

}

enum TextureRepositoryError: Error {
    case notFound
    case failedToUnwrap
    case failedToLoadTexture
    case failedToAddTexture
    case failedToUpdateTexture
    case commandBufferFailed
    case invalidTexture
    case repositoryDeinitialized
    case repositoryUnavailable
}
