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

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.storageInitializationWithNewTexturePublisher
    }
    var canvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.canvasInitializationUsingConfigurationPublisher
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

    func initializeStorage(from configuration: CanvasConfiguration) {
        repository.initializeStorage(from: configuration)
    }

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, any Error> {
        repository.hasAllTextures(fileNames: fileNames)
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {
        repository.initializeStorageWithNewTexture(textureSize)
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
