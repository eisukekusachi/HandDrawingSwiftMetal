//
//  MockTextureLayerRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

import Combine
import UIKit
import Metal

final class MockTextureLayerRepository: TextureLayerRepository {

    let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    var textureNum: Int = 0

    var textureSize: CGSize = .zero

    var textureIds: Set<UUID> { Set([]) }

    var isInitialized: Bool = false

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeBlankTexture(with: device)
        else {
            return Fail(error: NSError(domain: "AddTextureError", code: -1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        return Just(
            .init(
                uuid: UUID(),
                texture: texture
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeBlankTexture(with: device)
        else {
            return Fail(error: NSError(domain: "AddTextureError", code: -1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        return Just(
            .init(
                uuid: UUID(),
                texture: texture
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[IdentifiedTexture], Error> {
        Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        Just(uuid).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeAll() {}

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {}

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeBlankTexture(with: device)
        else {
            return Fail(error: NSError(domain: "AddTextureError", code: -1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        return Just(
            .init(
                uuid: UUID(),
                texture: texture
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
