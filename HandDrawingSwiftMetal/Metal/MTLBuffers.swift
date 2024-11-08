//
//  MTLBuffers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import MetalKit

struct GrayscalePointBuffers {
    let vertexBuffer: MTLBuffer
    let diameterIncludingBlurBuffer: MTLBuffer
    let brightnessBuffer: MTLBuffer
    let blurSizeBuffer: MTLBuffer
    let numberOfPoints: Int
}

struct TextureBuffers {
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
    ) -> GrayscalePointBuffers? {
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
        nodes: MTLTextureNodes,
        with device: MTLDevice?
    ) -> TextureBuffers? {
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
        textureCoord: MTLTextureCoordinates = MTLTextureNodes.screenTextureCoordinates,
        indices: MTLTextureIndices = MTLTextureNodes.textureIndices,
        with device: MTLDevice?
    ) -> TextureBuffers? {
        guard let device else { return nil }

        // Calculate vertex positions for the four corners
        var leftBottom: CGPoint = .init(
            x: destinationSize.width * 0.5 + sourceSize.width * 0.5 * -1,
            y: destinationSize.height * 0.5 + sourceSize.height * 0.5 * 1
        )
        var rightBottom: CGPoint = .init(
            x: destinationSize.width * 0.5 + sourceSize.width * 0.5 * 1,
            y: destinationSize.height * 0.5 + sourceSize.height * 0.5 * 1
        )
        var rightTop: CGPoint = .init(
            x: destinationSize.width * 0.5 + sourceSize.width * 0.5 * 1,
            y: destinationSize.height * 0.5 + sourceSize.height * 0.5 * -1
        )

        var leftTop: CGPoint = .init(
            x: destinationSize.width * 0.5 + sourceSize.width * 0.5 * -1,
            y: destinationSize.height * 0.5 + sourceSize.height * 0.5 * -1
        )

        if let matrix {
            var matrix = matrix
            matrix.tx *= (CGFloat(destinationSize.width) / frameSize.width)
            matrix.ty *= (CGFloat(destinationSize.height) / frameSize.height)

            // Translate origin to the top left corner
            leftBottom = CGPoint(
                x: leftBottom.x - destinationSize.width * 0.5,
                y: leftBottom.y - destinationSize.height * 0.5
            )
            rightBottom = CGPoint(
                x: rightBottom.x - destinationSize.width * 0.5,
                y: rightBottom.y - destinationSize.height * 0.5
            )
            rightTop = CGPoint(
                x: rightTop.x - destinationSize.width * 0.5,
                y: rightTop.y - destinationSize.height * 0.5
            )
            leftTop = CGPoint(
                x: leftTop.x - destinationSize.width * 0.5,
                y: leftTop.y - destinationSize.height * 0.5
            )

            // Coordinate transformation
            leftBottom = CGPoint(
                x: (leftBottom.x * matrix.a + leftBottom.y * matrix.c + matrix.tx),
                y: (leftBottom.x * matrix.b + leftBottom.y * matrix.d + matrix.ty)
            )
            rightBottom = CGPoint(
                x: (rightBottom.x * matrix.a + rightBottom.y * matrix.c + matrix.tx),
                y: (rightBottom.x * matrix.b + rightBottom.y * matrix.d + matrix.ty)
            )
            rightTop = CGPoint(
                x: (rightTop.x * matrix.a + rightTop.y * matrix.c + matrix.tx),
                y: (rightTop.x * matrix.b + rightTop.y * matrix.d + matrix.ty)
            )
            leftTop = CGPoint(
                x: (leftTop.x * matrix.a + leftTop.y * matrix.c + matrix.tx),
                y: (leftTop.x * matrix.b + leftTop.y * matrix.d + matrix.ty)
            )

            // Translate origin back to the center
            leftBottom = CGPoint(
                x: leftBottom.x + destinationSize.width * 0.5,
                y: leftBottom.y + destinationSize.height * 0.5
            )
            rightBottom = CGPoint(
                x: rightBottom.x + destinationSize.width * 0.5,
                y: rightBottom.y + destinationSize.height * 0.5
            )
            rightTop = CGPoint(
                x: rightTop.x + destinationSize.width * 0.5,
                y: rightTop.y + destinationSize.height * 0.5
            )
            leftTop = CGPoint(
                x: leftTop.x + destinationSize.width * 0.5,
                y: leftTop.y + destinationSize.height * 0.5
            )
        }

        // Normalize vertex positions
        let vertices: [Float] = [
            Float(leftBottom.x / destinationSize.width) * 2.0 - 1.0,
            Float(leftBottom.y / destinationSize.height * 2.0 - 1.0),

            Float(rightBottom.x / destinationSize.width) * 2.0 - 1.0,
            Float(rightBottom.y / destinationSize.height) * 2.0 - 1.0,

            Float(rightTop.x / destinationSize.width) * 2.0 - 1.0,
            Float(rightTop.y / destinationSize.height) * 2.0 - 1.0,

            Float(leftTop.x / destinationSize.width) * 2.0 - 1.0,
            Float(leftTop.y / destinationSize.height) * 2.0 - 1.0
        ]

        let textureCoord = textureCoord.getValues()
        let indices = indices.getValues()

        // Create buffers
        guard
            let vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<Float>.size,
                options: []),
            let texCoordsBuffer = device.makeBuffer(
                bytes: textureCoord,
                length: textureCoord.count * MemoryLayout<Float>.size,
                options: []
            ),
            let indexBuffer = device.makeBuffer(
                bytes: indices,
                length: indices.count * MemoryLayout<UInt16>.size,
                options: []
            )
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
