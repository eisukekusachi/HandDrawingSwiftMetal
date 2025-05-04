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

    private let needsCanvasInitializationAfterNewTextureCreationSubject = PassthroughSubject<CGSize, Never>()

    private let needsCanvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsThumbnailUpdateSubject = PassthroughSubject<UUID, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> {
        needsCanvasInitializationAfterNewTextureCreationSubject.eraseToAnyPublisher()
    }

    var needsCanvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        needsCanvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
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

    func resolveCanvasView(from configuration: CanvasConfiguration, drawableSize: CGSize) {
        callHistory.append("resolveCanvasView(from: \(configuration), drawableSize: \(drawableSize))")
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

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize) {
        callHistory.append("initializeCanvasAfterCreatingNewTexture(\(textureSize)")
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

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        callHistory.append("removeTexture(\(uuid))")
        return Just(uuid)
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
