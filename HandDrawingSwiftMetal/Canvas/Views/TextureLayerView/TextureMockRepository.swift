//
//  TextureMockRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

import Combine
import UIKit
import Metal

final class TextureMockRepository: TextureRepository {
    var textureNum: Int = 0

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, any Error> {
        Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<(any MTLTexture)?, any Error> {
        Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        let result = uuids.reduce(into: [UUID: MTLTexture?]()) { $0[$1] = nil }
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        Just(uuid)
            .eraseToAnyPublisher()
    }

    func removeAll() {}

    func setThumbnail(texture: (any MTLTexture)?, for uuid: UUID) {}

    func setAllThumbnails() {}

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
