//
//  CanvasBrushDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
import Combine

/// A class used for real-time drawing on a texture using a brush
final class CanvasBrushDrawingTexture: CanvasDrawingTexture {

    var drawingFinishedPublisher: AnyPublisher<Void, Never> {
        drawingFinishedSubject.eraseToAnyPublisher()
    }

    private let drawingFinishedSubject = PassthroughSubject<Void, Never>()

    private var blushColor: UIColor = .black

    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init(renderer: MTLRendering) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension CanvasBrushDrawingTexture {

    func initTextures(_ textureSize: CGSize) {
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(with: commandBuffer)
        commandBuffer.commit()
    }

    func setBlushColor(_ color: UIColor) {
        blushColor = color
    }

    func drawCurvePointsUsingSelectedTexture(
        drawingCurvePoints: CanvasDrawingCurvePoints,
        selectedTexture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        drawCurvePointsOnDrawingTexture(
            points: drawingCurvePoints.makeCurvePointsFromIterator(),
            with: commandBuffer
        )

        drawDrawingTextureWithSelectedTexture(
            selectedTexture: selectedTexture,
            shouldUpdateSelectedTexture: drawingCurvePoints.isDrawingFinished,
            on: destinationTexture,
            with: commandBuffer
        )
    }

    func clearDrawingTextures(with commandBuffer: MTLCommandBuffer) {
        renderer.clearTextures(
            textures: [
                drawingTexture,
                grayscaleTexture
            ],
            with: commandBuffer
        )
    }

}

extension CanvasBrushDrawingTexture {

    private func drawCurvePointsOnDrawingTexture(
        points: [CanvasGrayscaleDotPoint],
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: MTLBuffers.makeGrayscalePointBuffers(
                points: points,
                alpha: blushColor.alpha,
                textureSize: drawingTexture.size,
                with: device
            ),
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            grayscaleTexture: grayscaleTexture,
            color: blushColor.rgb,
            on: drawingTexture,
            with: commandBuffer
        )
    }

    private func drawDrawingTextureWithSelectedTexture(
        selectedTexture: MTLTexture,
        shouldUpdateSelectedTexture: Bool,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawTexture(
            texture: selectedTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: destinationTexture,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: drawingTexture,
            into: destinationTexture,
            with: commandBuffer
        )

        if shouldUpdateSelectedTexture {
            renderer.mergeTexture(
                texture: drawingTexture,
                into: selectedTexture,
                with: commandBuffer
            )

            clearDrawingTextures(with: commandBuffer)

            drawingFinishedSubject.send(())
        }
    }

}
