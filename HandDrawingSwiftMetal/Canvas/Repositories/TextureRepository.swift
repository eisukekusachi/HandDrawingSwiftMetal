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

    var initializeCanvasWithModelPublisher: AnyPublisher<CanvasModel, Never> { get }
    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> { get }
    var updateCanvasPublisher: AnyPublisher<Void, Never> { get }

    /// Emit `UUID` when the thumbnail is updated
    var thumbnailWillChangePublisher: AnyPublisher<UUID, Never> { get }

    var textureNum: Int { get }
    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error>

    func restoreLayers(from model: CanvasModel, drawableSize: CGSize)

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error>
    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error>

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
