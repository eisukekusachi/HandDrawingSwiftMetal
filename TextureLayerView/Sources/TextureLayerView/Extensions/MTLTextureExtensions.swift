//
//  MTLTextureExtensions.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/22.
//

@preconcurrency import MetalKit

public extension MTLTexture {
    func data(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> Data {
        let width = self.width
        let height = self.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height

        guard
            let buffer = device.makeBuffer(length: dataSize, options: [.storageModeShared]),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
            Logger.error(error)
            throw error
        }

        commandEncoder.copy(
            from: self,
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

        return try await withCheckedThrowingContinuation { continuation in
            commandBuffer.addCompletedHandler { commandBuffer in
                if let error = commandBuffer.error {
                    continuation.resume(throwing: error)
                    return
                }

                let rawPointer = buffer.contents()
                let data = Data(bytes: rawPointer, count: dataSize)
                continuation.resume(returning: data)
            }

            commandBuffer.commit()
        }
    }
}
