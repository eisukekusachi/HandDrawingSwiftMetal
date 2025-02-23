//
//  CanvasDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

/// A protocol used for real-time drawing on a texture
protocol CanvasDrawingTexture {

    /// A publisher that emits `Void` when the drawing process is finished
    var canvasDrawFinishedPublisher: AnyPublisher<Void, Never> { get }

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    /// Draws a curve points on `destinationTexture` using the selected texture
    func drawCurvePointsUsingSelectedTexture(
        drawingCurvePoints: DrawingCurveIterator,
        selectedTexture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    /// Resets the real-time drawing textures
    func clearDrawingTextures(with commandBuffer: MTLCommandBuffer)

}
