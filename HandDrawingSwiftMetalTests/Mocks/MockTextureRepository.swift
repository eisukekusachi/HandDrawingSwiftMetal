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

    private let initializeCanvasAfterCreatingNewTextureSubject = PassthroughSubject<CGSize, Never>()

    private let restoreCanvasFromModelSubject = PassthroughSubject<CanvasModel, Never>()

    private let updateCanvasAfterTextureLayerUpdatesSubject = PassthroughSubject<Void, Never>()
    private let updateCanvasSubject = PassthroughSubject<Void, Never>()
    private let thumbnailWillChangeSubject = PassthroughSubject<UUID, Never>()

    var initializeCanvasAfterCreatingNewTexturePublisher: AnyPublisher<CGSize, Never> {
        initializeCanvasAfterCreatingNewTextureSubject.eraseToAnyPublisher()
    }
    var restoreCanvasFromModelPublisher: AnyPublisher<CanvasModel, Never> {
        restoreCanvasFromModelSubject.eraseToAnyPublisher()
    }

    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> {
        updateCanvasAfterTextureLayerUpdatesSubject.eraseToAnyPublisher()
    }

    var updateCanvasPublisher: AnyPublisher<Void, Never> {
        updateCanvasSubject.eraseToAnyPublisher()
    }

    var thumbnailWillChangePublisher: AnyPublisher<UUID, Never> {
        thumbnailWillChangeSubject.eraseToAnyPublisher()
    }

    var textures: [UUID: MTLTexture?] = [:]

    var callHistory: [String] = []

    var textureSize: CGSize? = nil

    var textureNum: Int = 0

    init(textures: [UUID : MTLTexture?] = [:]) {
        self.textures = textures
    }

    func resolveCanvasView(from model: HandDrawingSwiftMetal.CanvasModel, drawableSize: CGSize) {
        callHistory.append("resolveCanvasView(from: \(model), drawableSize: \(drawableSize))")
    }

    func updateCanvasAfterTextureLayerUpdates() {
        callHistory.append("updateCanvasAfterTextureLayerUpdates()")
        updateCanvasAfterTextureLayerUpdatesSubject.send(())
    }

    func updateCanvas() {
        callHistory.append("updateCanvas()")
        updateCanvasSubject.send(())
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

    func initTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, any Error> {
        callHistory.append("initTexture(uuid: \(uuid), textureSize: \(textureSize))")
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, Error> {
        callHistory.append("initTextures(layers: \(layers.count), textureSize: \(textureSize), folder: \(folderURL.lastPathComponent))")
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

    func setAllThumbnails() {
        callHistory.append("setAllThumbnails()")
    }

    func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
