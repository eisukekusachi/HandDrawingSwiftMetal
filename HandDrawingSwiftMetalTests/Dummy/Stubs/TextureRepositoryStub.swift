//
//  Created by Eisuke Kusachi
//

import Core
import CoreGraphics
import Foundation
import MetalKit

final class TextureRepositoryStub: MTLTextureDataRepositoryProtocol, @unchecked Sendable {

    var removedIds: [UUID] = []
    var restoreTexturesError: (any Error)?
    private(set) var restoreTexturesCalls: [(ids: [UUID], textureSize: CGSize)] = []

    func initializeTexture(
        id: UUID,
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {}

    func restoreTextures(
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws {
        restoreTexturesCalls.append((ids, textureSize))
        if let restoreTexturesError {
            throw restoreTexturesError
        }
    }

    func duplicatedTexture(
        _ id: UUID,
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw NSError(domain: "TextureRepositoryStub", code: 1)
        }
        return texture
    }

    func duplicatedTextures(
        _ ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> [(UUID, MTLTexture)] { [] }

    func addTextureData(data: Data, id: UUID) async throws -> Bool { true }

    func removeTexture(_ id: UUID) throws -> Bool {
        removedIds.append(id)
        return true
    }

    func removeAll() throws {}

    func copyTexture(id: UUID, to: URL) async throws -> Bool { false }

    func writeDataToDisk(id: UUID, data: Data) async throws {}
}
