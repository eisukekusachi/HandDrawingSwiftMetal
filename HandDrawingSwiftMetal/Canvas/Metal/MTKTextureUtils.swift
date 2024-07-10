//
//  MTKTextureUtils.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit
import Accelerate

enum MTKTextureUtils {
    static func makeTexture(_ device: MTLDevice, _ size: CGSize, _ pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [
            .renderTarget,
            .shaderRead,
            .shaderWrite]
        return device.makeTexture(descriptor: textureDescriptor)
    }
    static func makeTexture(_ device: MTLDevice, fromBundleImage imageName: String) -> MTLTexture? {
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

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let texture = device.makeTexture(descriptor: textureDescriptor)
        texture?.replace(region: MTLRegionMake2D(0, 0, w, h),
                         mipmapLevel: 0,
                         slice: 0,
                         withBytes: bgraBytes,
                         bytesPerRow: bytesPerRow,
                         bytesPerImage: bytesPerRow * h)
        rgbaBytes.deallocate()
        bgraBytes.deallocate()

        return texture
    }
    static func makeTexture(_ device: MTLDevice, _ size: CGSize, _ array: [UInt8]) -> MTLTexture? {
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let texture = device.makeTexture(descriptor: textureDescriptor)
        texture?.replace(region: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0,
                         slice: 0,
                         withBytes: array,
                         bytesPerRow: bytesPerRow,
                         bytesPerImage: bytesPerRow * height)
        return texture
    }
    static func makeTexture(_ device: MTLDevice, url: URL, textureSize: CGSize) throws -> MTLTexture? {
        guard let textureData = try Data(contentsOf: url).encodedHexadecimals else { return nil }
        return MTKTextureUtils.makeTexture(device, textureSize, textureData)
    }

    static func makeBlankTexture(_ device: MTLDevice, _ textureSize: CGSize) -> MTLTexture {
        let texture = MTKTextureUtils.makeTexture(device, textureSize)!

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        Command.clear(texture: texture,
                      commandBuffer)
        commandBuffer.commit()

        return texture
    }

    static func duplicateTexture(_ device: MTLDevice, _ sourceTexture: MTLTexture?) -> MTLTexture? {
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
              let sourceTexture else { return nil }

        let newTexture = MTKTextureUtils.makeTexture(device, sourceTexture.size)

        Command.copy(
            dst: newTexture,
            src: sourceTexture,
            commandBuffer)
        commandBuffer.commit()

        return newTexture
    }

}
