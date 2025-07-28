//
//  MockTextureLayerRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

@preconcurrency import Combine
import UIKit
import Metal

final class MockTextureLayerRepository: TextureLayerRepository, @unchecked Sendable {

    let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    var textureNum: Int = 0

    var textureSize: CGSize = .zero

    var textureIds: Set<UUID> { Set([]) }

    var isInitialized: Bool = false

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: CanvasConfiguration) async throws -> CanvasConfiguration {
        .init()
    }

    func restoreStorage(from sourceFolderURL: URL, with configuration: CanvasConfiguration) async throws {}

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {}

    func thumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func removeAll() {}

    func setThumbnail(texture: MTLTexture?, for uuid: UUID) {}

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeBlankTexture(with: device)
        else {
            throw NSError(domain: "AddTextureError", code: -1, userInfo: nil)
        }
        return .init(
            uuid: UUID(),
            texture: texture
        )
    }

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) async throws -> [IdentifiedTexture] {
        []
    }


    func removeTexture(_ uuid: UUID) throws -> UUID {
        uuid
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeBlankTexture(with: device)
        else {
            throw NSError(domain: "AddTextureError", code: -1, userInfo: nil)
        }
        return .init(
            uuid: UUID(),
            texture: texture
        )
    }

    @discardableResult func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let texture = MTLTextureCreator.makeBlankTexture(with: device)
        else {
            throw NSError(domain: "MockTextureLayerRepository", code: -1, userInfo: nil)
        }
        return .init(
            uuid: UUID(),
            texture: texture
        )
    }
}
