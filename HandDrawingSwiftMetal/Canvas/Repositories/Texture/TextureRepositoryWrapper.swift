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

    var storageInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.storageInitializationUsingConfigurationPublisher
    }

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        repository.storageInitializationWithNewTexturePublisher
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

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {
        repository.initializeStorageWithNewTexture(textureSize)
    }

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, any Error> {
        repository.hasAllTextures(fileNames: fileNames)
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

    func loadTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<(any MTLTexture)?, any Error> {
        repository.loadTexture(uuid: uuid, textureSize: textureSize)
    }

    func loadTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        repository.loadTextures(uuids: uuids, textureSize: textureSize)
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

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }

    func updateCanvasAfterTextureLayerUpdates() {
        repository.updateCanvasAfterTextureLayerUpdates()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        repository.updateAllThumbnails(textureSize: textureSize)
    }

    func updateCanvas() {
        repository.updateCanvas()
    }

}
