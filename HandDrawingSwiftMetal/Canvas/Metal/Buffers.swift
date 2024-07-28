//
//  MakingBuffer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

import MetalKit

typealias GrayscalePointBuffers2 = (
    vertexBuffer: MTLBuffer,
    diameterIncludingBlurBuffer: MTLBuffer,
    alphaBuffer: MTLBuffer,
    blurSize: Float,
    numberOfPoints: Int
)

enum Buffers {
    static func makeGrayscalePointBuffers(
        device: MTLDevice?,
        points: [DotPoint],
        blurredDotSize: BlurredDotSize,
        alpha: Int,
        textureSize: CGSize
    ) -> GrayscalePointBuffers2? {
        guard points.count != .zero else { return nil }

        var vertexArray: [Float] = []
        var alphaArray: [Float] = []
        var diameterPlusBlurSizeArray: [Float] = []

        points.forEach {
            let vertexX: Float = Float($0.location.x / textureSize.width) * 2.0 - 1.0
            let vertexY: Float = Float($0.location.y / textureSize.height) * 2.0 - 1.0

            vertexArray.append(contentsOf: [vertexX, vertexY])
            alphaArray.append(Float($0.alpha) * Float(alpha) / 255.0)
            diameterPlusBlurSizeArray.append(blurredDotSize.diameterIncludingBlurSize)
        }

        let vertexBuffer = device?.makeBuffer(
            bytes: vertexArray,
            length: vertexArray.count * MemoryLayout<Float>.size
        )
        let transparencyBuffer = device?.makeBuffer(
            bytes: alphaArray,
            length: alphaArray.count * MemoryLayout<Float>.size
        )
        let diameterPlusBlurSizeBuffer = device?.makeBuffer(
            bytes: diameterPlusBlurSizeArray,
            length: diameterPlusBlurSizeArray.count * MemoryLayout<Float>.size
        )

        guard
            let vertexBuffer,
            let transparencyBuffer,
            let diameterPlusBlurSizeBuffer
        else { return nil }

        return GrayscalePointBuffers2(
            vertexBuffer: vertexBuffer,
            diameterIncludingBlurBuffer: diameterPlusBlurSizeBuffer,
            alphaBuffer: transparencyBuffer,
            blurSize: blurredDotSize.blurSize,
            numberOfPoints: vertexArray.count / 2
        )
    }
    
    static func makeTextureBuffers(device: MTLDevice?,
                                   nodes: TextureNodes) -> TextureBuffers? {
        let vertices = nodes.vertices
        let texCoords = nodes.texCoords
        let indices = nodes.indices
        
        if let vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size),
           let texCoordsBuffer = device?.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size),
           let indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size) {
            
            return TextureBuffers(vertexBuffer: vertexBuffer,
                                  texCoordsBuffer: texCoordsBuffer,
                                  indexBuffer: indexBuffer,
                                  indicesCount: indices.count)
        } else {
            return nil
        }
    }
    
    static func makeTextureBuffers(device: MTLDevice?,
                                   textureSize: CGSize,
                                   drawableSize: CGSize,
                                   matrix: CGAffineTransform?,
                                   nodes: TextureNodes) -> TextureBuffers? {
        let texCoords = nodes.texCoords
        let indices = nodes.indices
        
        
        let scale = Aspect.getScaleToFill(textureSize, to: drawableSize)
        let drawableCoordTextureSize = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        
        
        let vlbx = drawableSize.width * 0.5 - drawableCoordTextureSize.width * 0.5
        let vlby = drawableSize.height * 0.5 + drawableCoordTextureSize.height * 0.5
        
        let vrbx = drawableSize.width * 0.5 + drawableCoordTextureSize.width * 0.5
        let vrby = drawableSize.height * 0.5 + drawableCoordTextureSize.height * 0.5
        
        let vrtx = drawableSize.width * 0.5 + drawableCoordTextureSize.width * 0.5
        let vrty = drawableSize.height * 0.5 - drawableCoordTextureSize.height * 0.5
        
        let vltx = drawableSize.width * 0.5 - drawableCoordTextureSize.width * 0.5
        let vlty = drawableSize.height * 0.5 - drawableCoordTextureSize.height * 0.5
        
        var vlb = CGPoint(x: vlbx, y: vlby)
        var vrb = CGPoint(x: vrbx, y: vrby)
        var vrt = CGPoint(x: vrtx, y: vrty)
        var vlt = CGPoint(x: vltx, y: vlty)
        
        
        if let matrix = matrix {
            vlb = CGPoint(x: vlb.x - drawableSize.width * 0.5,
                          y: vlb.y - drawableSize.height * 0.5)
            vrb = CGPoint(x: vrb.x - drawableSize.width * 0.5,
                          y: vrb.y - drawableSize.height * 0.5)
            vrt = CGPoint(x: vrt.x - drawableSize.width * 0.5,
                          y: vrt.y - drawableSize.height * 0.5)
            vlt = CGPoint(x: vlt.x - drawableSize.width * 0.5,
                          y: vlt.y - drawableSize.height * 0.5)
            
            vlb = CGPoint(x: (vlb.x * matrix.a + vlb.y * matrix.c + matrix.tx),
                          y: (vlb.x * matrix.b + vlb.y * matrix.d + matrix.ty))
            
            vrb = CGPoint(x: (vrb.x * matrix.a + vrb.y * matrix.c + matrix.tx),
                          y: (vrb.x * matrix.b + vrb.y * matrix.d + matrix.ty))
            
            vrt = CGPoint(x: (vrt.x * matrix.a + vrt.y * matrix.c + matrix.tx),
                          y: (vrt.x * matrix.b + vrt.y * matrix.d + matrix.ty))
            
            vlt = CGPoint(x: (vlt.x * matrix.a + vlt.y * matrix.c + matrix.tx),
                          y: (vlt.x * matrix.b + vlt.y * matrix.d + matrix.ty))
            
            vlb = CGPoint(x: vlb.x + drawableSize.width * 0.5,
                          y: vlb.y + drawableSize.height * 0.5)
            vrb = CGPoint(x: vrb.x + drawableSize.width * 0.5,
                          y: vrb.y + drawableSize.height * 0.5)
            vrt = CGPoint(x: vrt.x + drawableSize.width * 0.5,
                          y: vrt.y + drawableSize.height * 0.5)
            vlt = CGPoint(x: vlt.x + drawableSize.width * 0.5,
                          y: vlt.y + drawableSize.height * 0.5)
        }
        
        let vertices: [Float] = [
            Float(vlb.x / drawableSize.width * 2.0 - 1.0), Float(vlb.y / drawableSize.height * 2.0 - 1.0),
            Float(vrb.x / drawableSize.width * 2.0 - 1.0), Float(vrb.y / drawableSize.height * 2.0 - 1.0),
            Float(vrt.x / drawableSize.width * 2.0 - 1.0), Float(vrt.y / drawableSize.height * 2.0 - 1.0),
            Float(vlt.x / drawableSize.width * 2.0 - 1.0), Float(vlt.y / drawableSize.height * 2.0 - 1.0)
        ]
        
        if let vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size),
           let texCoordsBuffer = device?.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size),
           let indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size) {
            
            return TextureBuffers(vertexBuffer: vertexBuffer,
                                  texCoordsBuffer: texCoordsBuffer,
                                  indexBuffer: indexBuffer,
                                  indicesCount: indices.count)
        } else {
            return nil
        }
    }

    static func makeTextureRenderingBuffers(
        device: MTLDevice?,
        matrix: CGAffineTransform?,
        sourceSize: CGSize,
        destinationSize: CGSize,
        nodes: TextureNodes
    ) -> TextureBuffers? {
        guard let device = device else { return nil }

        let texCoords = nodes.texCoords
        let indices = nodes.indices

        // Helper function to calculate vertex coordinates
        func calculateVertexPosition(xOffset: CGFloat, yOffset: CGFloat) -> CGPoint {
            let x = destinationSize.width * 0.5 + xOffset * sourceSize.width * 0.5
            let y = destinationSize.height * 0.5 + yOffset * sourceSize.height * 0.5
            return CGPoint(x: x, y: y)
        }

        // Calculate vertex positions for the four corners
        var bottomLeft = calculateVertexPosition(xOffset: -1, yOffset: 1)
        var bottomRight = calculateVertexPosition(xOffset: 1, yOffset: 1)
        var topRight = calculateVertexPosition(xOffset: 1, yOffset: -1)
        var topLeft = calculateVertexPosition(xOffset: -1, yOffset: -1)

        if let matrix = matrix {
            // Translate origin to the top left corner
            bottomLeft = CGPoint(
                x: bottomLeft.x - destinationSize.width * 0.5,
                y: bottomLeft.y - destinationSize.height * 0.5
            )
            bottomRight = CGPoint(
                x: bottomRight.x - destinationSize.width * 0.5,
                y: bottomRight.y - destinationSize.height * 0.5
            )
            topRight = CGPoint(
                x: topRight.x - destinationSize.width * 0.5,
                y: topRight.y - destinationSize.height * 0.5
            )
            topLeft = CGPoint(
                x: topLeft.x - destinationSize.width * 0.5,
                y: topLeft.y - destinationSize.height * 0.5
            )

            // Coordinate transformation
            bottomLeft = CGPoint(
                x: (bottomLeft.x * matrix.a + bottomLeft.y * matrix.c + matrix.tx),
                y: (bottomLeft.x * matrix.b + bottomLeft.y * matrix.d + matrix.ty)
            )
            bottomRight = CGPoint(
                x: (bottomRight.x * matrix.a + bottomRight.y * matrix.c + matrix.tx),
                y: (bottomRight.x * matrix.b + bottomRight.y * matrix.d + matrix.ty)
            )
            topRight = CGPoint(
                x: (topRight.x * matrix.a + topRight.y * matrix.c + matrix.tx),
                y: (topRight.x * matrix.b + topRight.y * matrix.d + matrix.ty)
            )
            topLeft = CGPoint(
                x: (topLeft.x * matrix.a + topLeft.y * matrix.c + matrix.tx),
                y: (topLeft.x * matrix.b + topLeft.y * matrix.d + matrix.ty)
            )

            // Translate origin back to the center
            bottomLeft = CGPoint(
                x: bottomLeft.x + destinationSize.width * 0.5,
                y: bottomLeft.y + destinationSize.height * 0.5
            )
            bottomRight = CGPoint(
                x: bottomRight.x + destinationSize.width * 0.5,
                y: bottomRight.y + destinationSize.height * 0.5
            )
            topRight = CGPoint(
                x: topRight.x + destinationSize.width * 0.5,
                y: topRight.y + destinationSize.height * 0.5
            )
            topLeft = CGPoint(
                x: topLeft.x + destinationSize.width * 0.5,
                y: topLeft.y + destinationSize.height * 0.5
            )
        }

        // Normalize vertex positions to OpenGL coordinates
        let vertices: [Float] = [
            Float(bottomLeft.x / destinationSize.width * 2.0 - 1.0), Float(bottomLeft.y / destinationSize.height * 2.0 - 1.0),
            Float(bottomRight.x / destinationSize.width * 2.0 - 1.0), Float(bottomRight.y / destinationSize.height * 2.0 - 1.0),
            Float(topRight.x / destinationSize.width * 2.0 - 1.0), Float(topRight.y / destinationSize.height * 2.0 - 1.0),
            Float(topLeft.x / destinationSize.width * 2.0 - 1.0), Float(topLeft.y / destinationSize.height * 2.0 - 1.0)
        ]

        // Create buffers
        guard
            let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: []),
            let texCoordsBuffer = device.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size, options: []),
            let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
        else {
            return nil
        }

        return TextureBuffers(
            vertexBuffer: vertexBuffer,
            texCoordsBuffer: texCoordsBuffer,
            indexBuffer: indexBuffer,
            indicesCount: indices.count
        )
    }

}
