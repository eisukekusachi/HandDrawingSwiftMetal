//
//  MTLTextureExtensions.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/22.
//

@preconcurrency import Accelerate
@preconcurrency import MetalKit

extension MTLTexture {
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

    func makeThumbnail(length: Int = 128) -> UIImage? {
        upsideDownUIImage?.resizeWithAspectRatio(
            width: CGFloat(length),
            scale: 1.0
        )
    }
}

private extension MTLTexture {
    var upsideDownUIImage: UIImage? {
        let width = self.width
        let height = self.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height
        let region = MTLRegionMake2D(0, 0, width, height)

        var bgraBytes = [UInt8](repeating: 0, count: totalBytes)
        var rgbaBytes = [UInt8](repeating: 0, count: totalBytes)
        var flippedBytes = [UInt8](repeating: 0, count: totalBytes)

        self.getBytes(
            &bgraBytes,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        let result: vImage_Error = bgraBytes.withUnsafeMutableBytes { bgraRawBuffer in
            rgbaBytes.withUnsafeMutableBytes { rgbaRawBuffer in
                flippedBytes.withUnsafeMutableBytes { flippedRawBuffer in
                    guard
                        let bgraBase = bgraRawBuffer.baseAddress,
                        let rgbaBase = rgbaRawBuffer.baseAddress,
                        let flippedBase = flippedRawBuffer.baseAddress
                    else {
                        return kvImageNullPointerArgument
                    }

                    var bgraBuffer = vImage_Buffer(
                        data: bgraBase,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: bytesPerRow
                    )

                    var rgbaBuffer = vImage_Buffer(
                        data: rgbaBase,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: bytesPerRow
                    )

                    var flippedBuffer = vImage_Buffer(
                        data: flippedBase,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: bytesPerRow
                    )

                    // BGRA -> RGBA
                    let map: [UInt8] = [2, 1, 0, 3]
                    let permuteError = map.withUnsafeBufferPointer { mapBuffer in
                        vImagePermuteChannels_ARGB8888(
                            &bgraBuffer,
                            &rgbaBuffer,
                            mapBuffer.baseAddress!,
                            vImage_Flags(kvImageNoFlags)
                        )
                    }
                    guard permuteError == kvImageNoError else {
                        return permuteError
                    }

                    // Flip vertically
                    return vImageVerticalReflect_ARGB8888(
                        &rgbaBuffer,
                        &flippedBuffer,
                        vImage_Flags(kvImageNoFlags)
                    )
                }
            }
        }

        guard result == kvImageNoError else {
            return nil
        }

        let data = Data(flippedBytes)
        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
