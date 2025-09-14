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

    func addTexture(_ texture: (any MTLTexture)?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        .init(
            uuid: uuid,
            texture: texture!
        )
    }

    func removeTexture(_ uuid: UUID) -> UUID {
        uuid
    }

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
        configuration: TextureLayserArrayConfiguration,
        fallbackTextureSize: CGSize
    ) async throws -> ResolvedTextureLayserArrayConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? fallbackTextureSize
        )
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: TextureLayserArrayConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> ResolvedTextureLayserArrayConfiguration {
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
        let context = try MockMetalContext()
        let mockTexture = try context.makeTexture(width: 16, height: 16)
        return  .init(
            uuid: UUID(),
            texture: mockTexture
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
        let context = try MockMetalContext()
        let mockTexture = try context.makeTexture(width: 16, height: 16)
        callHistory.append("updateTexture(texture: \(texture?.label ?? "nil"), for: \(uuid))")
        return  .init(
            uuid: UUID(),
            texture: texture ?? mockTexture
        )
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
