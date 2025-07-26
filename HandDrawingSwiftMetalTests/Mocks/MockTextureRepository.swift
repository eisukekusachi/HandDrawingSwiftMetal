//
//  MockTextureRepository.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Metal
import UIKit
@testable import HandDrawingSwiftMetal

final class MockTextureRepository: TextureRepository {

    let objectWillChangeSubject = PassthroughSubject<Void, Never>()

    var textures: [UUID: MTLTexture] = [:]

    var textureIds: Set<UUID> = Set([])

    var callHistory: [String] = []

    var textureSize: CGSize = .zero

    var textureNum: Int = 0

    var isInitialized: Bool { false }

    init(textures: [UUID : MTLTexture] = [:]) {
        self.textures = textures
    }

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) -> AnyPublisher<CanvasConfiguration, Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        callHistory.append("addTexture(\(uuid))")
        return Just(
            .init(
                uuid: UUID(),
                texture: texture!
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        let device = MTLCreateSystemDefaultDevice()!
        return Just(
            .init(
                uuid: uuid,
                texture: textures[uuid] ?? (MTLTextureCreator.makeBlankTexture(with: device)!)
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[IdentifiedTexture], Error> {
        let device = MTLCreateSystemDefaultDevice()!
        return Just(uuids.map { uuid in
            .init(
                uuid: uuid,
                texture: textures[uuid] ?? MTLTextureCreator.makeBlankTexture(with: device)!
            )
        })
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    
    func thumbnail(_ uuid: UUID) -> UIImage? {
        callHistory.append("thumbnail(\(uuid))")
        return nil
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<MTLTexture?, Error> {
        callHistory.append("loadTexture(\(uuid))")
        let resultTexture: MTLTexture? = textures[uuid].flatMap { $0 }
        return Just(resultTexture)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        callHistory.append("removeTexture(\(uuid))")
        return Just(uuid).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeAll() {
        callHistory.append("removeAll()")
    }

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        callHistory.append("setThumbnail(texture: \(texture?.label ?? "nil"), for: \(uuid))")
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        let device = MTLCreateSystemDefaultDevice()!
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return  .init(
            uuid: UUID(),
            texture: MTLTextureCreator.makeBlankTexture(with: device)!
        )
    }
}
