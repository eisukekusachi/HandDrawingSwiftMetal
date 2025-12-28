//
//  MockTextureRepository.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import Metal
import UIKit

@MainActor
final class MockTextureRepository: @unchecked Sendable {

    var textures: [LayerId: MTLTexture] = [:]
    var callHistory: [String] = []
    var textureSize: CGSize = .zero
    var isInitialized: Bool { false }

    init(textures: [LayerId : MTLTexture] = [:]) {
        self.textures = textures
    }

    private func recordCall(_ function: StaticString = #function) {
        callHistory.append("\(function)")
    }

    func removeTexture(_ id: LayerId) throws {
        recordCall()
    }

    func setTextureSize(_ size: CGSize) {
        recordCall()
    }

    func initializeStorage(
        textureLayersPersistedState: TextureLayersPersistedState,
        fallbackTextureSize: CGSize
    ) async throws {
        recordCall()
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        textureLayersPersistedState: TextureLayersPersistedState,
        fallbackTextureSize: CGSize
    ) async throws {
        recordCall()
    }

    func addTexture(_ texture: MTLTexture, id: LayerId) async throws {
        recordCall()
    }

    func newTexture(_ textureSize: CGSize) async throws -> MTLTexture {
        recordCall()
        let context = try MockMetalContext()
        return try context.makeTexture(width: 16, height: 16)
    }

    func thumbnail(_ id: LayerId) -> UIImage? {
        recordCall()
        return nil
    }

    func loadTexture(_ id: LayerId) -> AnyPublisher<MTLTexture?, Error> {
        recordCall()
        let resultTexture: MTLTexture? = textures[id]
        return Just(resultTexture)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture {
        recordCall()
        let context = try MockMetalContext()
        let mockTexture = try context.makeTexture(width: 16, height: 16)
        return .init(id: id, texture: mockTexture)
    }

    func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture] {
        recordCall()
        return []
    }

    func removeAll() {
        recordCall()
    }

    func setThumbnail(texture: MTLTexture?, for id: LayerId) {
        recordCall()
    }

    func updateTexture(texture: MTLTexture, for id: LayerId) async throws {
        recordCall()
    }
}

private struct MockMetalContext {
    let device: MTLDevice
    let queue: MTLCommandQueue

    enum TestMetalError: Error {
        case noDevice
        case noTexture
    }

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw TestMetalError.noDevice }
        guard let queue = device.makeCommandQueue() else { throw TestMetalError.noDevice }
        self.device = device
        self.queue = queue
    }

    func makeTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]
    ) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType   = .type2D
        descriptor.pixelFormat   = pixelFormat
        descriptor.width         = width
        descriptor.height        = height
        descriptor.usage         = usage
        descriptor.storageMode   = .shared
        descriptor.cpuCacheMode  = .defaultCache

        guard
            let texture = device.makeTexture(descriptor: descriptor)
        else {
            throw TestMetalError.noTexture
        }
        return texture
    }

    func fill(
        texture: MTLTexture,
        rgba: (UInt8, UInt8, UInt8, UInt8)
    ) {
        let bytesPerPixel = 4
        let bytesPerRow = texture.width * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * texture.height)
        for y in 0 ..< texture.height {
            let rowStart = y * bytesPerRow
            for x in 0 ..< texture.width {
                let i = rowStart + x * bytesPerPixel
                buffer[i + 0] = rgba.0
                buffer[i + 1] = rgba.1
                buffer[i + 2] = rgba.2
                buffer[i + 3] = rgba.3
            }
        }
        buffer.withUnsafeBytes { ptr in
            texture.replace(
                region: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: bytesPerRow
            )
        }
    }
}
