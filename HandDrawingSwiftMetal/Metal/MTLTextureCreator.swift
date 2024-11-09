//
//  MTLTextureCreator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit
import Accelerate

enum MTLTextureCreator {

    static let pixelFormat: MTLPixelFormat = .bgra8Unorm

    static func makeTexture(size: CGSize, pixelFormat: MTLPixelFormat = pixelFormat, with device: MTLDevice) -> MTLTexture? {
        device.makeTexture(
            descriptor: getTextureDescriptor(size: size)
        )
    }
    static func makeTexture(fromBundleImage imageName: String, with device: MTLDevice) -> MTLTexture? {
        guard let image = UIImage(named: imageName)?.cgImage else {
            return nil
        }

        let (w, h) = (Int(image.width), Int(image.height))
        let map: [UInt8] = [2, 1, 0, 3]
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let bitsPerComponent = 8
        let totalNumBytes: Int = h * w * bytesPerPixel
        let rgbaBytes: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: totalNumBytes)
        let bgraBytes: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: totalNumBytes)

        rgbaBytes.deallocate()
        bgraBytes.deallocate()

        let context = CGContext(data: rgbaBytes,
                                width: w,
                                height: h,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        var bgraBuffer = vImage_Buffer(data: bgraBytes,
                                       height: vImagePixelCount(image.height),
                                       width: vImagePixelCount(image.width),
                                       rowBytes: bytesPerRow)

        var rgbaBuffer = vImage_Buffer(data: rgbaBytes,
                                       height: vImagePixelCount(image.height),
                                       width: vImagePixelCount(image.width),
                                       rowBytes: bytesPerRow)

        vImagePermuteChannels_ARGB8888(&rgbaBuffer, &bgraBuffer, map, 0)

        let texture = device.makeTexture(
            descriptor: getTextureDescriptor(size: .init(width: w, height: h))
        )
        texture?.replace(region: MTLRegionMake2D(0, 0, w, h),
                         mipmapLevel: 0,
                         slice: 0,
                         withBytes: bgraBytes,
                         bytesPerRow: bytesPerRow,
                         bytesPerImage: bytesPerRow * h)
        return texture
    }
    static func makeTexture(size: CGSize, array: [UInt8], with device: MTLDevice) -> MTLTexture? {
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        let texture = device.makeTexture(
            descriptor: getTextureDescriptor(size: .init(width: width, height: height))
        )
        texture?.replace(region: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0,
                         slice: 0,
                         withBytes: array,
                         bytesPerRow: bytesPerRow,
                         bytesPerImage: bytesPerRow * height)
        return texture
    }

    static func makeBlankTexture(
        size: CGSize,
        with device: MTLDevice
    ) -> MTLTexture? {
        guard
            let texture = makeTexture(size: size, with: device),
            let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer()
        else { return nil }

        MTLRenderer.clearTexture(
            texture: texture,
            with: commandBuffer
        )
        commandBuffer.commit()

        return texture
    }

    static func duplicateTexture(
        texture: MTLTexture?,
        with device: MTLDevice
    ) -> MTLTexture? {
        guard
            let texture,
            let newTexture = makeTexture(size: texture.size, with: device),
            let flippedTextureBuffers: MTLTextureBuffers = MTLBuffers.makeTextureBuffers(
                nodes: .flippedTextureNodes,
                with: device
            ),
            let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer()
        else { return nil }

        MTLRenderer.drawTexture(
            texture: texture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: newTexture,
            with: commandBuffer
        )

        commandBuffer.commit()

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
