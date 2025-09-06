//
//  MockTextureRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

import CanvasView
import UIKit
import Metal

final class MockTextureRepository: TextureRepository, @unchecked Sendable {

    var textureNum: Int = 0

    var textureSize: CGSize = .zero

    var textureIds: Set<UUID> { Set([]) }

    var isInitialized: Bool = false

    func setTextureSize(_ size: CGSize) {}

    func initializeStorage(configuration: ProjectConfiguration, fallbackTextureSize: CGSize) async throws -> ResolvedProjectConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? fallbackTextureSize
        )
    }

    func restoreStorage(
        from sourceFolderURL: URL,
        configuration: ProjectConfiguration,
        defaultTextureSize: CGSize
    ) async throws -> ResolvedProjectConfiguration {
        try await .init(
            configuration: configuration,
            resolvedTextureSize: configuration.textureSize ?? defaultTextureSize
        )
    }

    func createTexture(uuid: UUID, textureSize: CGSize) async throws {}

    func removeAll() {}

    /// Copies a texture for the given UUID
    func copyTexture(uuid: UUID) async throws -> IdentifiedTexture {
        let context = try MockMetalContext()
        let texture = try context.makeTexture(width: 16, height: 16)
        return .init(
            uuid: uuid,
            texture: texture
        )
    }

    /// Copies multiple textures for the given UUIDs
    func copyTextures(uuids: [UUID]) async throws -> [IdentifiedTexture] {
        []
    }


    func removeTexture(_ uuid: UUID) -> UUID {
        uuid
    }

    func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        let context = try MockMetalContext()
        let texture = try context.makeTexture(width: 16, height: 16)
        return .init(
            uuid: UUID(),
            texture: texture
        )
    }

    @discardableResult func updateTexture(texture: MTLTexture?, for uuid: UUID) async throws -> IdentifiedTexture {
        let context = try MockMetalContext()
        let texture = try context.makeTexture(width: 16, height: 16)
        return .init(
            uuid: UUID(),
            texture: texture
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
