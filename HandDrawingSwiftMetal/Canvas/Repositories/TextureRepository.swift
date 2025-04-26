//
//  TextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Foundation
import MetalKit

protocol TextureRepository {

    var textureNum: Int { get }

    /// Create a new texture and initialize the canvas
    var initializeCanvasAfterCreatingNewTexturePublisher: AnyPublisher<CGSize, Never> { get }

    /// Restore the canvas from the model
    var restoreCanvasFromModelPublisher: AnyPublisher<CanvasModel, Never> { get }

    /// Emit `UUID` when the thumbnail is updated
    var thumbnailWillChangePublisher: AnyPublisher<UUID, Never> { get }

    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> { get }
    var updateCanvasPublisher: AnyPublisher<Void, Never> { get }

    /// Resolve the state of the CanvasView
    func resolveCanvasView(from model: CanvasModel, drawableSize: CGSize)

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize)

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error>
    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error>

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error>

    func getThumbnail(_ uuid: UUID) -> UIImage?

    func loadTexture(_ uuid: UUID) -> AnyPublisher<MTLTexture?, Error>
    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID: MTLTexture?], Error>

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never>
    func removeAll()

    func setThumbnail(texture: MTLTexture?, for uuid: UUID)
    func setAllThumbnails()

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error>

    func updateCanvasAfterTextureLayerUpdates()

    func updateCanvas()

}

enum TextureRepositoryError: Error {
    case notFound
    case failedToUnwrap
    case failedToLoadTexture
    case failedToAddTexture
    case repositoryDeinitialized
}
