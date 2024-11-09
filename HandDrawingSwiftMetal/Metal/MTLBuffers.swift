//
//  MTLBuffers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import MetalKit

struct MTLGrayscalePointBuffers {
    let vertexBuffer: MTLBuffer
    let diameterIncludingBlurBuffer: MTLBuffer
    let brightnessBuffer: MTLBuffer
    let blurSizeBuffer: MTLBuffer
    let numberOfPoints: Int
}

struct MTLTextureBuffers {
    let vertexBuffer: MTLBuffer
    let texCoordsBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indicesCount: Int
}

enum MTLBuffers {
    static func makeGrayscalePointBuffers(
        points: [CanvasGrayscaleDotPoint],
        alpha: Int,
        textureSize: CGSize,
        with device: MTLDevice?
    ) -> MTLGrayscalePointBuffers? {
        guard points.count != .zero else { return nil }

        var vertexArray: [Float] = []
        var alphaArray: [Float] = []
        var blurSizeArray: [Float] = []
        var diameterIncludingBlurSizeArray: [Float] = []

        points.forEach {
            let vertexX: Float = Float($0.location.x / textureSize.width) * 2.0 - 1.0
            let vertexY: Float = Float($0.location.y / textureSize.height) * 2.0 - 1.0

            vertexArray.append(contentsOf: [vertexX, vertexY])
            alphaArray.append(Float($0.brightness) * Float(alpha) / 255.0)
            diameterIncludingBlurSizeArray.append(
                BlurredDotSize(diameter: Float($0.diameter), blurSize: Float($0.blurSize)).diameterIncludingBlurSize
            )
            blurSizeArray.append(Float($0.blurSize))
        }

        let vertexBuffer = device?.makeBuffer(
            bytes: vertexArray,
            length: vertexArray.count * MemoryLayout<Float>.size
        )
        let diameterIncludingBlurSizeBuffer = device?.makeBuffer(
            bytes: diameterIncludingBlurSizeArray,
            length: diameterIncludingBlurSizeArray.count * MemoryLayout<Float>.size
        )
        let alphaBuffer = device?.makeBuffer(
            bytes: alphaArray,
            length: alphaArray.count * MemoryLayout<Float>.size
        )
        let blurSizeBuffer = device?.makeBuffer(
            bytes: blurSizeArray,
            length: blurSizeArray.count * MemoryLayout<Float>.size
        )

        guard
            let vertexBuffer,
            let diameterIncludingBlurSizeBuffer,
            let alphaBuffer,
            let blurSizeBuffer
        else { return nil }

        return .init(
            vertexBuffer: vertexBuffer,
            diameterIncludingBlurBuffer: diameterIncludingBlurSizeBuffer,
            brightnessBuffer: alphaBuffer,
            blurSizeBuffer: blurSizeBuffer,
            numberOfPoints: vertexArray.count / 2
        )
    }

    static func makeTextureBuffers(
        nodes: MTLTextureNodes = .textureNodes,
        with device: MTLDevice?
    ) -> MTLTextureBuffers? {
        let vertices = nodes.vertices.getValues()
        let texCoords = nodes.textureCoord.getValues()
        let indices = nodes.indices.getValues()

        guard
            let vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size),
            let texCoordsBuffer = device?.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size),
            let indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size)
        else { return nil }

        return .init(
            vertexBuffer: vertexBuffer,
            texCoordsBuffer: texCoordsBuffer,
            indexBuffer: indexBuffer,
            indicesCount: indices.count
        )
    }

    static func makeCanvasTextureBuffers(
        matrix: CGAffineTransform?,
        frameSize: CGSize,
        sourceSize: CGSize,
        destinationSize: CGSize,
        textureCoord: MTLTextureCoordinates = .screenTextureCoordinates,
        indices: MTLTextureIndices = .init(),
        with device: MTLDevice?
    ) -> MTLTextureBuffers? {
        let vertices: [Float] = MTLTextureVertices.makeCenterAlignedTextureVertices(
            matrix: matrix,
            frameSize: frameSize,
            sourceSize: sourceSize,
            destinationSize: destinationSize
        ).getValues()
        let textureCoord: [Float]  = textureCoord.getValues()
        let indices: [UInt16] = indices.getValues()

        guard
            let device,
            let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size),
            let texCoordsBuffer = device.makeBuffer(bytes: textureCoord, length: textureCoord.count * MemoryLayout<Float>.size),
            let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size)
        else {
            return nil
        }

        return .init(
            vertexBuffer: vertexBuffer,
            texCoordsBuffer: texCoordsBuffer,
            indexBuffer: indexBuffer,
            indicesCount: indices.count
        )
    }

}
