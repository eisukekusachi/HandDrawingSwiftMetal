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

    private let storageInitializationWithNewTextureSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let canvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let thumbnailUpdateRequestedSubject = PassthroughSubject<UUID, Never>()

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }

    var canvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        canvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
    }

    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> {
        thumbnailUpdateRequestedSubject.eraseToAnyPublisher()
    }

    var textures: [UUID: MTLTexture?] = [:]

    var callHistory: [String] = []

    var textureSize: CGSize = .zero

    var textureNum: Int = 0

    var hasTexturesBeenInitialized: Bool { false }

    init(textures: [UUID : MTLTexture?] = [:]) {
        self.textures = textures
    }

    func resolveCanvasView(from configuration: CanvasConfiguration, drawableSize: CGSize) {
        callHistory.append("resolveCanvasView(from: \(configuration), drawableSize: \(drawableSize))")
    }

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, Error> {
        return Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeStorageWithNewTexture(_ textureSize: CGSize) {
        callHistory.append("initializeStorageWithNewTexture(\(textureSize)")
    }

    func initializeTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeStorage(from configuration: HandDrawingSwiftMetal.CanvasConfiguration) {

    }

    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<(any MTLTexture)?, any Error> {
        return Just(textures[uuid] ?? MTLTextureCreator.makeBlankTexture(size: textureSize, with: device))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        let result = uuids.reduce(into: [UUID: MTLTexture?]()) { dict, uuid in
            dict[uuid] = textures[uuid] ?? MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
        }
        return Just(result)
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

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID: MTLTexture?], Error> {
        callHistory.append("loadTextures(\(uuids.count) uuids)")
        return Just(
            uuids.reduce(into: [:]) { dict, uuid in
                dict[uuid] = textures[uuid] ?? nil
            }
        )
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func loadNewTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, any Error> {
        return Just(())
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

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
