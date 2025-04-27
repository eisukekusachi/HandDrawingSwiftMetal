//
//  TextureInMemorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Foundation
import MetalKit

final class TextureInMemorySingletonRepository: ObservableObject, TextureRepository {

    static let shared = TextureInMemorySingletonRepository()

    private let repository: any TextureRepository

    private init(repository: any TextureRepository = TextureInMemoryRepository()) {
        self.repository = repository
    }

    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> {
        repository.needsCanvasInitializationAfterNewTextureCreationPublisher
    }
    var needsCanvasRestorationFromModelPublisher: AnyPublisher<CanvasModel, Never> {
        repository.needsCanvasRestorationFromModelPublisher
    }

    var needsCanvasUpdateAfterTextureLayerChangesPublisher: AnyPublisher<Void, Never> {
        repository.needsCanvasUpdateAfterTextureLayerChangesPublisher
    }
    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> {
        repository.needsCanvasUpdatePublisher
    }

    var needsThumbnailUpdatePublisher: AnyPublisher<UUID, Never> {
        repository.needsThumbnailUpdatePublisher
    }

    var textureNum: Int {
        repository.textureNum
    }
    var textureSize: CGSize {
        repository.textureSize
    }

    func resolveCanvasView(from model: CanvasModel, drawableSize: CGSize) {
        repository.resolveCanvasView(from: model, drawableSize: drawableSize)
    }

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, any Error> {
        repository.hasAllTextures(for: uuids)
    }

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize) {
        repository.initializeCanvasAfterCreatingNewTexture(textureSize)
    }

    func initializeTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        repository.initializeTexture(uuid: uuid, textureSize: textureSize)
    }

    func initializeTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        repository.initializeTextures(layers: layers, textureSize: textureSize, folderURL: folderURL)
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        repository.getThumbnail(uuid)
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<(any MTLTexture)?, any Error> {
        repository.loadTexture(uuid)
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        repository.loadTextures(uuids)
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        repository.removeTexture(uuid)
    }

    func removeAll() {
        repository.removeAll()
    }

    func setThumbnail(texture: (any MTLTexture)?, for uuid: UUID) {
        repository.setThumbnail(texture: texture, for: uuid)
    }

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }

    func updateCanvasAfterTextureLayerUpdates() {
        repository.updateCanvasAfterTextureLayerUpdates()
    }

    func updateCanvas() {
        repository.updateCanvas()
    }

}
