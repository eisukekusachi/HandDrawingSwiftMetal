//
//  CanvasDrawingBrushTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
import Combine

/// A set of textures for real-time brush drawing
final class CanvasDrawingBrushTextureSet: CanvasDrawingTextureSet {

    var canvasDrawFinishedPublisher: AnyPublisher<Void, Never> {
        canvasDrawFinishedSubject.eraseToAnyPublisher()
    }

    private let canvasDrawFinishedSubject = PassthroughSubject<Void, Never>()

    private var blushColor: UIColor = .black

    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init(renderer: MTLRendering = MTLRenderer.shared) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension CanvasDrawingBrushTextureSet {

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

    func drawCurvePoints(
        drawingCurveIterator: DrawingCurveIterator,
        withBackgroundTexture backgroundTexture: MTLTexture,
        withBackgroundColor backgroundColor: UIColor = .clear,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        drawCurvePointsOnDrawingTexture(
            points: drawingCurveIterator.makeCurvePointsFromIterator(),
            with: commandBuffer
        )

        drawDrawingTextureWithBackgroundTexture(
            backgroundTexture: backgroundTexture,
            backgroundColor: backgroundColor,
            shouldUpdateSelectedTexture: drawingCurveIterator.isDrawingFinished,
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

extension CanvasDrawingBrushTextureSet {

    private func drawCurvePointsOnDrawingTexture(
        points: [GrayscaleDotPoint],
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

    private func drawDrawingTextureWithBackgroundTexture(
        backgroundTexture: MTLTexture,
        backgroundColor: UIColor = .clear,
        shouldUpdateSelectedTexture: Bool,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawTexture(
            texture: backgroundTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: backgroundColor,
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
                into: backgroundTexture,
                with: commandBuffer
            )

            clearDrawingTextures(with: commandBuffer)

            canvasDrawFinishedSubject.send(())
        }
    }

}
