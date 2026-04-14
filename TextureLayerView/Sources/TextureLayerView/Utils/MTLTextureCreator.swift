//
//  MTLTextureCreator.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/21.
//

@preconcurrency import MetalKit

private let bytesPerPixel = 4
private let bitsPerComponent = 8

enum MTLTextureCreator {

    static func loadHexadecimalData(
        from url: URL
    ) throws -> [UInt8]? {
        guard let hexadecimalData = try Data(contentsOf: url).encodedHexadecimals else {
            return nil
        }
        return hexadecimalData
    }

    static func makeTexture(
        label: String? = nil,
        url: URL,
        size: CGSize,
        with device: MTLDevice
    ) throws -> MTLTexture? {
        guard
            let hexadecimalData = try loadHexadecimalData(from: url)
        else { return nil }
        return try MTLTextureCreator.makeTexture(
            label: label,
            width: Int(size.width),
            height: Int(size.height),
            from: hexadecimalData,
            with: device
        )
    }

    static func makeTexture(
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

    static func makeTexture(
        label: String? = nil,
        width: Int,
        height: Int,
        from colorArray: [UInt8],
        with device: MTLDevice
    ) throws -> MTLTexture? {
        guard colorArray.count == width * height * bytesPerPixel else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid value")
            )
            Logger.error(error)
            return nil
        }

        let bytesPerRow = bytesPerPixel * width

        guard let texture = makeTexture(
            label: label,
            width: width,
            height: height,
            with: device
        ) else {
            return nil
        }

        colorArray.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                slice: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerRow * height
            )
        }

        return texture
    }
}
