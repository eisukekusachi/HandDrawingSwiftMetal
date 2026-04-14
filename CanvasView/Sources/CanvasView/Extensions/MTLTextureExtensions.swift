//
//  MTLTextureExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

@preconcurrency import Accelerate
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

    var size: CGSize {
        return CGSize(width: self.width, height: self.height)
    }
    
    var bytes: [UInt8] {
        let bytesPerPixel = 4

        let imageByteCount = self.width * self.height * bytesPerPixel
        let bytesPerRow = self.width * bytesPerPixel

        var result = [UInt8](repeating: 0, count: Int(imageByteCount))
        let region = MTLRegionMake2D(0, 0, self.width, self.height)

        self.getBytes(&result, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        return result
    }
    var uiImage: UIImage? {
        guard let data = UIImage.makeCFData(self, flipY: true),
              let image = UIImage.makeImage(cfData: data,
                                            width: self.width,
                                            height: self.height) else { return nil }
        return image
    }
    var upsideDownUIImage: UIImage? {
        let width = self.width
        let height = self.height
        let numComponents = 4
        let bytesPerRow = width * numComponents
        let totalBytes = bytesPerRow * height
        let region = MTLRegionMake2D(0, 0, width, height)
        var bgraBytes = [UInt8](repeating: 0, count: totalBytes)
        self.getBytes(&bgraBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        // use Accelerate framework to convert from BGRA to RGBA
        var bgraBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: bgraBytes),
                    height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        let rgbaBytes = [UInt8](repeating: 0, count: totalBytes)
        var rgbaBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: rgbaBytes),
                    height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        let map: [UInt8] = [2, 1, 0, 3]
        vImagePermuteChannels_ARGB8888(&bgraBuffer, &rgbaBuffer, map, 0)
        // flipping image vertically
        let flippedBytes = bgraBytes // share the buffer
        var flippedBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: flippedBytes),
                    height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: bytesPerRow)
        vImageVerticalReflect_ARGB8888(&rgbaBuffer, &flippedBuffer, 0)
        // create CGImage with RGBA Flipped Bytes
        guard let data = CFDataCreate(nil, flippedBytes, totalBytes) else { return nil }
        guard let dataProvider = CGDataProvider(data: data) else { return nil }
        let cgImage = CGImage(width: self.width,
                              height: self.height,
                              bitsPerComponent: 8,
                              bitsPerPixel: 8 * numComponents,
                              bytesPerRow: bytesPerRow,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                              provider: dataProvider,
                              decode: nil,
                              shouldInterpolate: true,
                              intent: .defaultIntent)
        guard let cgImage = cgImage else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func makeThumbnail(length: Int = 128) -> UIImage? {
        upsideDownUIImage?.resizeWithAspectRatio(
            width: CGFloat(length),
            scale: 1.0
        )
    }
}
