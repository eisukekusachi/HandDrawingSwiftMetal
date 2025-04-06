//
//  CanvasDrawingTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit

/// A protocol for a set of textures for real-time drawing
protocol CanvasDrawingTextureSet {

    /// A publisher that emits `Void` when the drawing process is finished
    var canvasDrawFinishedPublisher: AnyPublisher<Void, Never> { get }

    var drawingSelectedTexture: MTLTexture { get }

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    /// Draws a curve points on `destinationTexture` using the selected texture
    func drawCurvePoints(
        drawingCurveIterator: DrawingCurveIterator,
        withBackgroundTexture backgroundTexture: MTLTexture?,
        withBackgroundColor backgroundColor: UIColor,
        with commandBuffer: MTLCommandBuffer
    )

    /// Resets the real-time drawing textures
    func clearDrawingTextures(with commandBuffer: MTLCommandBuffer)

}
