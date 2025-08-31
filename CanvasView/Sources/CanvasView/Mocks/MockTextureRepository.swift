//
//  MockTextureRepository.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import UIKit
@preconcurrency import Combine
@preconcurrency import Metal

final class MockTextureRepository: TextureRepository, @unchecked Sendable {

    func addTexture(_ texture: (any MTLTexture)?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        .init(
            uuid: uuid,
            texture: texture!
        )
    }

    func removeTexture(_ uuid: UUID) -> UUID {
        uuid
    }

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

    func initializeStorage(
        configuration: CanvasConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> CanvasResolvedConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? defaultTextureSize
        )
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: CanvasConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> CanvasResolvedConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? defaultTextureSize
        )
    }

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {}

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

    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        let device = MTLCreateSystemDefaultDevice()!
        return  .init(
            uuid: UUID(),
            texture: MTLTextureCreator.makeBlankTexture(
                size: .init(width: canvasMinimumTextureLength, height: canvasMinimumTextureLength),
                with: device
            )!
        )
    }

    func copyTextures(uuids: [UUID]) async throws -> [IdentifiedTexture] {
        []
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
            texture: MTLTextureCreator.makeBlankTexture(
                size: .init(width: canvasMinimumTextureLength, height: canvasMinimumTextureLength),
                with: device
            )!
        )
    }
}
