//
//  TextureRepositoryWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Combine
import UIKit

class TextureRepositoryWrapper: ObservableObject, TextureRepository {

    let repository: any TextureRepository

    init(repository: any TextureRepository) {
        self.repository = repository
    }

    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> {
        repository.needsCanvasInitializationAfterNewTextureCreationPublisher
    }
    var needsCanvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.needsCanvasInitializationUsingConfigurationPublisher
    }

    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> {
        repository.needsCanvasUpdateAfterTextureLayersUpdatedPublisher
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

    func resolveCanvasView(from configuration: CanvasConfiguration, drawableSize: CGSize) {
        repository.resolveCanvasView(from: configuration, drawableSize: drawableSize)
    }

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, any Error> {
        repository.hasAllTextures(for: uuids)
    }

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize) {
        repository.initializeCanvasAfterCreatingNewTexture(textureSize)
    }

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        repository.createTexture(uuid: uuid, textureSize: textureSize)
    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        repository.createTextures(layers: layers, textureSize: textureSize, folderURL: folderURL)
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

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        repository.removeTexture(uuid)
    }

    func removeAll() {
        repository.removeAll()
    }

    func setThumbnail(texture: (any MTLTexture)?, for uuid: UUID) {
        repository.setThumbnail(texture: texture, for: uuid)
    }

    func updateTextureAsync(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        repository.updateTextureAsync(texture: texture, for: uuid)
    }

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) throws {
        try repository.updateTexture(texture: texture, for: uuid)
    }

    func updateCanvasAfterTextureLayerUpdates() {
        repository.updateCanvasAfterTextureLayerUpdates()
    }

    func updateCanvas() {
        repository.updateCanvas()
    }

}
