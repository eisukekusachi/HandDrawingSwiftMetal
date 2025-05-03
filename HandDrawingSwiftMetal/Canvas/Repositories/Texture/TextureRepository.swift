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

    /// The common size used for all textures
    var textureSize: CGSize { get }

    /// A publisher that emits to trigger the creation of a new texture and initialization of the canvas
    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> { get }

    /// A publisher that emits to trigger restoration of the canvas from `CanvasConfiguration`
    var needsCanvasRestorationFromConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> { get }

    /// A publisher that emits to update texture layers and update the canvas
    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> { get }

    /// A publisher that emits to trigger the canvas update
    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> { get }

    /// A publisher that notifies SwiftUI about a thumbnail update for a specific layer
    var needsThumbnailUpdatePublisher: AnyPublisher<UUID, Never> { get }

    /// Resolves the state of the canvas view
    func resolveCanvasView(from configuration: CanvasConfiguration, drawableSize: CGSize)

    /// Initializes the canvas after creating a new texture
    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize)

    /// Initializes a texture
    func initializeTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error>

    /// Initializes textures for the given layers using a folder URL as a source
    func initializeTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error>

    /// Checks if all specified textures exist
    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error>

    /// Retrieves the thumbnail image for UUID
    func getThumbnail(_ uuid: UUID) -> UIImage?

    /// Loads a texture for the given UUID
    func loadTexture(_ uuid: UUID) -> AnyPublisher<MTLTexture?, Error>

    /// Loads multiple textures for the given UUIDs
    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID: MTLTexture?], Error>

    /// Removes a texture with UUID
    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never>

    /// Removes all managed textures
    func removeAll()

    /// Sets a thumbnail image for UUID based on the provided texture
    func setThumbnail(texture: MTLTexture?, for uuid: UUID)

    /// Updates an existing texture for UUID
    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error>

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
    case repositoryDeinitialized
}
