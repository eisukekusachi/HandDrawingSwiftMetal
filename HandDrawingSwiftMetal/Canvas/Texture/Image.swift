//
//  Image.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/05.
//

import Foundation
import MetalKit
import Accelerate

enum Image {
    
    static func makeCFData(_ texture: MTLTexture?, flipY: Bool = false) -> CFData? {
        guard let texture = texture else { return nil }
        
        let width = texture.width
        let height = texture.height
        let numComponents = 4
        let bytesPerRow = width * numComponents
        let totalBytes = bytesPerRow * height
        let region = MTLRegionMake2D(0, 0, width, height)
        
        var bgraBytes = [UInt8](repeating: 0, count: totalBytes)
        var rgbaBytes = [UInt8](repeating: 0, count: totalBytes)
        var flippedBytes = [UInt8](repeating: 0, count: totalBytes)
        
        texture.getBytes(&bgraBytes,
                         bytesPerRow: bytesPerRow,
                         from: region,
                         mipmapLevel: 0)
        
        var bgraBuffer: vImage_Buffer?
        var rgbaBuffer: vImage_Buffer?
        var flippedBuffer: vImage_Buffer?
        
        bgraBytes.withUnsafeMutableBytes { texArrayPtr in
            if let pointer = texArrayPtr.baseAddress {
                bgraBuffer = vImage_Buffer(data: pointer,
                                           height: vImagePixelCount(height),
                                           width: vImagePixelCount(width),
                                           rowBytes: bytesPerRow)
            }
        }
        
        rgbaBytes.withUnsafeMutableBytes { texArrayPtr in
            if let pointer = texArrayPtr.baseAddress {
                rgbaBuffer = vImage_Buffer(data: pointer,
                                           height: vImagePixelCount(height),
                                           width: vImagePixelCount(width),
                                           rowBytes: bytesPerRow)
            }
        }
        
        
        guard var bgraBuffer = bgraBuffer,
              var rgbaBuffer = rgbaBuffer else { return nil }
        
        let map: [UInt8] = [2, 1, 0, 3]
        vImagePermuteChannels_ARGB8888(&bgraBuffer, &rgbaBuffer, map, 0)
        
        
        var cfData: CFData?
        
        if flipY {
            flippedBytes.withUnsafeMutableBytes { texArrayPtr in
                if let pointer = texArrayPtr.baseAddress {
                    flippedBuffer = vImage_Buffer(data: pointer,
                                                  height: vImagePixelCount(height),
                                                  width: vImagePixelCount(width),
                                                  rowBytes: bytesPerRow)
                }
            }
            
            if var flippedBuffer = flippedBuffer {
                vImageVerticalReflect_ARGB8888(&rgbaBuffer, &flippedBuffer, 0)
                cfData = CFDataCreate(nil, flippedBytes, totalBytes)
            }
        }
        
        if cfData == nil {
            cfData = CFDataCreate(nil, rgbaBytes, totalBytes)
        }
        return cfData
    }
    static func makeImage(cfData: CFData?, width: Int, height: Int, numComponents: Int = 4) -> UIImage? {
        
        guard let cfData = cfData,
              let dataProvider = CGDataProvider(data: cfData) else { return nil }
        
        if let cgImage = CGImage(width: width,
                                 height: height,
                                 bitsPerComponent: 8,
                                 bitsPerPixel: 8 * numComponents,
                                 bytesPerRow: width * numComponents,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: dataProvider,
                                 decode: nil,
                                 shouldInterpolate: true,
                                 intent: .defaultIntent) {
                return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
}
