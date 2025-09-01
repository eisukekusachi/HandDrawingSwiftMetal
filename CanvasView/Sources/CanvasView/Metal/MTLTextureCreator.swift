//
//  MTLTextureCreator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit
import Accelerate

private let bytesPerPixel = 4
private let bitsPerComponent = 8

public enum MTLTextureCreator {

    public static func makeTexture(
        label: String? = nil,
        width: Int,
        height: Int,
        with device: MTLDevice
    ) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [
            .renderTarget,
            .shaderRead,
            .shaderWrite
        ]

        let texture = device.makeTexture(
            descriptor: textureDescriptor
        )
        texture?.label = label
        return texture
    }

    public static func makeTexture(
        label: String? = nil,
        width: Int,
        height: Int,
        from colorArray: [UInt8],
        with device: MTLDevice
    ) -> MTLTexture? {
        guard colorArray.count == Int(width * height) * bytesPerPixel else { return nil }

        let bytesPerRow = bytesPerPixel * width

        let texture = makeTexture(
            label: label,
            width: width,
            height: height,
            with: device
        )
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
}
