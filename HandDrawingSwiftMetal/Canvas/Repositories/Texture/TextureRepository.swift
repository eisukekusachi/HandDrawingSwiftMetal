//
//  TextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Foundation
import MetalKit

/// A repository that manages textures and related canvas operations
protocol TextureRepository {

    /// The number of textures currently managed
    var textureNum: Int { get }

    /// A publisher that emits to trigger initialization of the storage using `CanvasConfiguration`
    var storageInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// A publisher that emits to trigger initialization of the storage using `CanvasConfiguration`
    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// A publisher that emits to update texture layers and update the canvas
    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> { get }

    /// A publisher that emits to trigger the canvas update
    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> { get }

    /// A publisher that notifies SwiftUI about a thumbnail update for a specific layer
    var needsThumbnailUpdatePublisher: AnyPublisher<UUID, Never> { get }

    /// Initialized the storage
    func initializeStorage(from configuration: CanvasConfiguration)

    /// Initialized the storage with a new texture
    func initializeStorageWithNewTexture(_ textureSize: CGSize)

    /// Creates a texture
    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error>

    /// Creates textures for the given layers using a folder URL as a source
    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error>

    /// Checks if all specified textures exist
    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, Error>

    /// Retrieves the thumbnail image for UUID
    func getThumbnail(_ uuid: UUID) -> UIImage?

    /// Loads a texture for the given UUID
    func loadTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error>

    /// Loads multiple textures for the given UUIDs
    func loadTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID: MTLTexture?], Error>

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error>

    /// Removes all managed textures
    func removeAll()

    /// Sets a thumbnail image for UUID based on the provided texture
    func setThumbnail(texture: MTLTexture?, for uuid: UUID)

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error>

    /// Updates all thumbnails
    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error>

    /// Update texture layers and then update the canvas
    func updateCanvasAfterTextureLayerUpdates()

    /// Updates the canvas
    func updateCanvas()
}

enum TextureRepositoryError: Error {
    case notFound
    case failedToUnwrap
    case failedToLoadTexture
    case failedToAddTexture
    case failedToUpdateTexture
    case invalidTexture
    case repositoryDeinitialized
    case repositoryUnavailable
}
