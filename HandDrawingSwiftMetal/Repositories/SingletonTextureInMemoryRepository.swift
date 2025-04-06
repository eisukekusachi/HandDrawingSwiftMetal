//
//  SingletonTextureInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Foundation
import MetalKit

final class SingletonTextureInMemoryRepository: ObservableObject, TextureRepository {

    static let shared = SingletonTextureInMemoryRepository()

    private let repository: any TextureRepository

    private init(repository: any TextureRepository = TextureInMemoryRepository()) {
        self.repository = repository
    }

    var textureNum: Int {
        repository.textureNum
    }

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, any Error> {
        repository.hasAllTextures(for: uuids)
    }

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        repository.initTexture(uuid: uuid, textureSize: textureSize)
    }

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        repository.initTextures(layers: layers, textureSize: textureSize, folderURL: folderURL)
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

    func setAllThumbnails() {
        repository.setAllThumbnails()
    }

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        repository.updateTexture(texture: texture, for: uuid)
    }

}
