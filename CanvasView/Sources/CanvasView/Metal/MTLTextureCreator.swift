//
//  MTLTextureCreator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

@preconcurrency import Accelerate
@preconcurrency import MetalKit

private let bytesPerPixel = 4
private let bitsPerComponent = 8

public enum MTLTextureCreator {

    static func makeTexture(
        url: URL,
        textureSize: CGSize,
        with device: MTLDevice
    ) throws -> MTLTexture? {
        guard
            let hexadecimalData = try Data(contentsOf: url).encodedHexadecimals
        else { return nil }
        return try MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            from: hexadecimalData,
            with: device
        )
    }

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
    ) throws -> MTLTexture? {
        guard colorArray.count == Int(width * height) * bytesPerPixel else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            return nil
        }

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

    @MainActor
    public static func duplicateTexture(
        texture: MTLTexture,
        renderer: MTLRendering
    ) async throws -> MTLTexture? {
        guard
            let device = renderer.device,
            let newCommandBuffer = renderer.newCommandBuffer,
            let resultTexture = MTLTextureCreator.makeTexture(
                label: texture.label,
                width: texture.width,
                height: texture.height,
                with: device
            )
        else {
            return nil
        }

        guard
            texture.pixelFormat == resultTexture.pixelFormat && texture.sampleCount == resultTexture.sampleCount
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            return nil
        }

        renderer.copyTexture(
            srcTexture: texture,
            dstTexture: resultTexture,
            with: newCommandBuffer
        )

        try await newCommandBuffer.commitAndWaitAsync()

        return resultTexture
    }
}
