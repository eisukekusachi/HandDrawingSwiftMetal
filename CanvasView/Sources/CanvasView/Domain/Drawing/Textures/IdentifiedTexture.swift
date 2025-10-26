//
//  IdentifiedTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

@preconcurrency import MetalKit

/// A struct that represents a texture entity with `UUID` and `MTLTexture`
public struct IdentifiedTexture: Hashable, @unchecked Sendable {
    public let id: UUID
    public let texture: MTLTexture

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: IdentifiedTexture, rhs: IdentifiedTexture) -> Bool {
        lhs.id == rhs.id
    }

    /// Converts a single IdentifiedTexture to a dictionary [UUID: MTLTexture]
    static func dictionary(from item: IdentifiedTexture) -> [UUID: MTLTexture] {
        [item.id: item.texture]
    }

    /// Converts a Set of IdentifiedTexture to a dictionary [UUID: MTLTexture]
    static func dictionary(from set: Set<IdentifiedTexture>) -> [UUID: MTLTexture] {
        Dictionary(
            uniqueKeysWithValues: set.compactMap { item in
                return (item.id, item.texture)
            }
        )
    }

    public init(id: UUID, texture: MTLTexture) {
        self.id = id
        self.texture = texture
    }
}

extension IdentifiedTexture: LocalTextureConvertible {
    public var fileName: String {
        id.uuidString
    }

    public func write(
        in directory: URL,
        device: MTLDevice?
    ) async throws {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height

        guard
            let device,
            let buffer = device.makeBuffer(length: dataSize, options: [.storageModeShared]),
            let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        commandEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: dataSize
        )
        commandEncoder.endEncoding()

        try await commandBuffer.commitAndWaitAsync()

        let rawPointer = buffer.contents()
        let data = Data(bytes: rawPointer, count: dataSize)

        try data.write(
            to: directory.appendingPathComponent(fileName),
            options: .atomic
        )
    }
}
