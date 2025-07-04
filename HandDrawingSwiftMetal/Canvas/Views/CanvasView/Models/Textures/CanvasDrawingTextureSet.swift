//
//  CanvasDrawingTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit

/// A protocol for a set of textures for realtime drawing
protocol CanvasDrawingTextureSet {

    /// A publisher that emits the realtime drawing texture when it is updated
    var realtimeDrawingTexturePublisher: AnyPublisher<MTLTexture?, Never> { get }

    /// Initializes the textures for realtime drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    /// Updates the realtime drawing texture by curve points from the given iterator
    func updateRealTimeDrawingTexture(
        singleCurveIterator: SingleCurveIterator,
        baseTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer,
        onDrawingCompleted: (() -> Void)?
    )

    /// Resets the realtime drawing textures
    func clearTextures(with commandBuffer: MTLCommandBuffer)

}
