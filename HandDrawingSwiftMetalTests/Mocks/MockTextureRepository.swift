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

    func initializeStorage(from configuration: HandDrawingSwiftMetal.CanvasConfiguration) {}
    
    func initializeStorageWithNewTexture(_ textureSize: CGSize) {}

    func hasAllTextures(fileNames: [String]) -> AnyPublisher<Bool, any Error> {
        return Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<MTLTexture?, Error> {
        return Just(textures[uuid] ?? MTLTextureCreator.makeBlankTexture(size: textureSize, with: device))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getTextures(uuids: [UUID], textureSize: CGSize) -> AnyPublisher<[UUID :MTLTexture?], Error> {
        let result = uuids.reduce(into: [UUID: MTLTexture?]()) { dict, uuid in
            dict[uuid] = textures[uuid] ?? MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
        }
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    private let storageInitializationWithNewTextureSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let canvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsThumbnailUpdateSubject = PassthroughSubject<UUID, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    var storageInitializationWithNewTexturePublisher: AnyPublisher<CanvasConfiguration, Never> {
        storageInitializationWithNewTextureSubject.eraseToAnyPublisher()
    }

    var canvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        canvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
    }

    var needsThumbnailUpdatePublisher: AnyPublisher<UUID, Never> {
        needsThumbnailUpdateSubject.eraseToAnyPublisher()
    }

    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.eraseToAnyPublisher()
    }

    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateSubject.eraseToAnyPublisher()
    }

    var textures: [UUID: MTLTexture?] = [:]

    var callHistory: [String] = []

    var textureSize: CGSize = .zero

    var textureNum: Int = 0

    init(textures: [UUID : MTLTexture?] = [:]) {
        self.textures = textures
    }

    func initializeStorage(from configuration: CanvasConfiguration, drawableSize: CGSize) {
        callHistory.append("initializeStorage(from: \(configuration), drawableSize: \(drawableSize))")
    }

    func updateCanvasAfterTextureLayerUpdates() {
        callHistory.append("updateCanvasAfterTextureLayerUpdates()")
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.send(())
    }

    func updateCanvas() {
        callHistory.append("updateCanvas()")
        needsCanvasUpdateSubject.send(())
    }

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, Error> {
        callHistory.append("hasAllTextures(for: \(uuids.map { $0.uuidString }))")
        return Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        callHistory.append("getThumbnail(\(uuid))")
        return nil
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

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
