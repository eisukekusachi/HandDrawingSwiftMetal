//
//  MockTextureRepository.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import UIKit
import Metal

final class MockTextureRepository: TextureRepository, @unchecked Sendable {

    func removeTexture(_ id: LayerId) throws {}

    var textures: [LayerId: MTLTexture] = [:]

    var callHistory: [String] = []

    var textureSize: CGSize = .zero

    var isInitialized: Bool { false }

    init(
        textures: [LayerId : MTLTexture] = [:]
    ) {
        self.textures = textures
    }

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(
        configuration: TextureLayerArrayConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? fallbackTextureSize
        )
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: TextureLayerArrayConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> ResolvedTextureLayerArrayConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? defaultTextureSize
        )
    }

    func addTexture(_ texture: MTLTexture, id: LayerId) async throws {}

    func newTexture(_ textureSize: CGSize) async throws -> MTLTexture {
        let context = try MockMetalContext()
        return try context.makeTexture(width: 16, height: 16)
    }

    func thumbnail(_ id: LayerId) -> UIImage? {
        callHistory.append("thumbnail(\(id))")
        return nil
    }

    func loadTexture(_ id: LayerId) -> AnyPublisher<MTLTexture?, Error> {
        callHistory.append("loadTexture(\(id))")
        let resultTexture: MTLTexture? = textures[id].flatMap { $0 }
        return Just(resultTexture)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture {
        let context = try MockMetalContext()
        let mockTexture = try context.makeTexture(width: 16, height: 16)
        return  .init(
            id: id,
            texture: mockTexture
        )
    }

    func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture] {
        []
    }

    func removeAll() {
        callHistory.append("removeAll()")
    }

    func setThumbnail(texture: MTLTexture?, for id: LayerId) {
        callHistory.append("setThumbnail(texture: \(texture?.label ?? "nil"), for: \(id))")
    }

    func updateTexture(texture: MTLTexture, for id: LayerId) async throws {
        callHistory.append("updateTexture(texture: \(texture.label ?? "nil"), for: \(id))")
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
