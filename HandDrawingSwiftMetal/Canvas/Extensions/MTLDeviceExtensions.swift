//
//  Texture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/12/25.
//

import MetalKit
import Accelerate

extension MTLDevice {
    
    func makeTexture(_ size: CGSize) -> MTLTexture? {
        let (w, h) = (Int(size.width), Int(size.height))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        return self.makeTexture(descriptor: descriptor)
    }
    
    func makeTexture(_ imageName: String) -> MTLTexture? {
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
        let texture = self.makeTexture(descriptor: textureDescriptor)
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
    
    func makeTexture(_ size: CGSize, _ array: [UInt8]?) -> MTLTexture? {
        guard let array = array else {
            return nil
        }
        
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        let texture = self.makeTexture(descriptor: textureDescriptor)
        texture?.replace(region: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0,
                         slice: 0,
                         withBytes: array,
                         bytesPerRow: bytesPerRow,
                         bytesPerImage: bytesPerRow * height)
        return texture
    }
}
