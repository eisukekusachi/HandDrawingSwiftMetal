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

    private let device = MTLCreateSystemDefaultDevice()!

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        objectWillChangeSubject.eraseToAnyPublisher()
    }
    private let objectWillChangeSubject = PassthroughSubject<Void, Never>()

    var textures: [UUID: MTLTexture?] = [:]

    var callHistory: [String] = []

    var textureSize: CGSize = .zero

    var textureNum: Int = 0

    var isInitialized: Bool { false }

    init(textures: [UUID : MTLTexture?] = [:]) {
        self.textures = textures
    }

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: CanvasConfiguration) -> AnyPublisher<CanvasConfiguration, any Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, any Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) -> AnyPublisher<CanvasConfiguration, any Error> {
        Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func addTexture(_ texture: (any MTLTexture)?, using uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, any Error> {
        callHistory.append("addTexture(\(uuid))")
        return Just(.init(uuid: UUID())).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func copyTexture(uuid: UUID) -> AnyPublisher<TextureRepositoryEntity, any Error> {
        Just(.init(uuid: UUID()))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func copyTextures(uuids: [UUID]) -> AnyPublisher<[TextureRepositoryEntity], Error> {
        Just(uuids.map { uuid in .init(uuid: uuid, texture: textures[uuid] ?? MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)) })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getThumbnail(_ uuid: UUID) -> UIImage? {
        callHistory.append("getThumbnail(\(uuid))")
        return nil
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<MTLTexture?, Error> {
        callHistory.append("loadTexture(\(uuid))")
        let resultTexture: MTLTexture? = textures[uuid]?.flatMap { $0 }
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

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
