//
//  MTLTextureCreator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit
import Accelerate

public enum MTLTextureCreator {

    public static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    public static let bytesPerPixel = 4
    public static let bitsPerComponent = 8

    public static func makeTexture(
        label: String? = nil,
        size: CGSize,
        pixelFormat: MTLPixelFormat = pixelFormat,
        with device: MTLDevice
    ) -> MTLTexture? {
        let texture = device.makeTexture(
            descriptor: getTextureDescriptor(size: size)
        )
        texture?.label = label
        return texture
    }

    public static func makeTexture(
        label: String? = nil,
        image: UIImage?,
        with device: MTLDevice
    ) -> MTLTexture? {
        guard
            let image,
            let cgImage = image.cgImage
        else { return nil }

        let width: Int = Int(image.size.width)
        let height: Int = Int(image.size.height)

        let map: [UInt8] = [2, 1, 0, 3]
        let bytesPerRow = bytesPerPixel * width
        let totalNumBytes: Int = width * height * bytesPerPixel

        let rgbaBytes: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: totalNumBytes)
        let bgraBytes: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: totalNumBytes)

        defer {
            rgbaBytes.deallocate()
            bgraBytes.deallocate()
        }

        let context = CGContext(
            data: rgbaBytes,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )

        context?.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        )

        var bgraBuffer = vImage_Buffer(
            data: bgraBytes,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )

        var rgbaBuffer = vImage_Buffer(
            data: rgbaBytes,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )

        vImagePermuteChannels_ARGB8888(&rgbaBuffer, &bgraBuffer, map, 0)

        let texture = makeTexture(label: label, size: image.size, with: device)
        texture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            slice: 0,
            withBytes: bgraBytes,
            bytesPerRow: bytesPerRow,
            bytesPerImage: bytesPerRow * height
        )
        return texture
    }

    public static func makeTexture(
        label: String? = nil,
        size: CGSize,
        colorArray: [UInt8],
        with device: MTLDevice
    ) -> MTLTexture? {
        guard colorArray.count == Int(size.width * size.height) * bytesPerPixel else { return nil }

        let width: Int = Int(size.width)
        let height: Int = Int(size.height)

        let bytesPerRow = bytesPerPixel * width

        let texture = makeTexture(label: label, size: .init(width: width, height: height), with: device)
        texture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            slice: 0,
            withBytes: colorArray,
            bytesPerRow: bytesPerRow,
            bytesPerImage: bytesPerRow * height
        )
        return texture
    }

    public static func makeBlankTexture(
        label: String? = nil,
        size: CGSize = MTLRenderer.minimumTextureSize,
        with device: MTLDevice
    ) -> MTLTexture? {
        guard
            Int(size.width) >= MTLRenderer.threadGroupLength &&
            Int(size.height) >= MTLRenderer.threadGroupLength
        else {
            Logger.error("\(String(localized: "Texture size is below the minimum", bundle: .module)):\(size.width) \(size.height)")
            return nil
        }

        guard
            let texture = makeTexture(label: label, size: size, with: device),
            let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer()
        else { return nil }

        MTLRenderer.shared.clearTexture(
            texture: texture,
            with: commandBuffer
        )
        commandBuffer.commit()

        return texture
    }

    static func duplicateTexture(
        texture: MTLTexture?,
        with device: MTLDevice?
    ) -> MTLTexture? {
        guard
            let commandBuffer = device?.makeCommandQueue()?.makeCommandBuffer(),
            let duplicateCurrentLayerTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                withDevice: device,
                withCommandBuffer: commandBuffer
            )
        else { return nil }

        commandBuffer.commit()

        return duplicateCurrentLayerTexture
    }
    static func duplicateTexture(
        texture: MTLTexture?,
        withDevice device: MTLDevice?,
        withCommandBuffer commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        guard
            let device,
            let texture,
            let newTexture = makeTexture(label: texture.label, size: texture.size, with: device),
            let flippedTextureBuffers: MTLTextureBuffers = MTLBuffers.makeTextureBuffers(
                nodes: .flippedTextureNodes,
                with: device
            )
        else { return nil }

        MTLRenderer.shared.drawTexture(
            texture: texture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: newTexture,
            with: commandBuffer
        )

        return newTexture
    }

    private static func getTextureDescriptor(size: CGSize) -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [
            .renderTarget,
            .shaderRead,
            .shaderWrite
        ]
        return textureDescriptor
    }

}
