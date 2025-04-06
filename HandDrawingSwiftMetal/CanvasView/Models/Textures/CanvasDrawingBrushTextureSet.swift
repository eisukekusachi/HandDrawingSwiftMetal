//
//  CanvasDrawingBrushTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for real-time brush drawing
final class CanvasDrawingBrushTextureSet: CanvasDrawingTextureSet {

    var canvasDrawFinishedPublisher: AnyPublisher<Void, Never> {
        canvasDrawFinishedSubject.eraseToAnyPublisher()
    }

    var drawingSelectedTexture: MTLTexture {
        resultTexture
    }

    private let canvasDrawFinishedSubject = PassthroughSubject<Void, Never>()

    private var blushColor: UIColor = .black

    private var resultTexture: MTLTexture!
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
        self.resultTexture = MTLTextureCreator.makeTexture(label: "resultTexture", size: textureSize, with: device)
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func setBlushColor(_ color: UIColor) {
        blushColor = color
    }

    func drawCurvePoints(
        drawingCurveIterator: DrawingCurveIterator,
        withBackgroundTexture backgroundTexture: MTLTexture?,
        withBackgroundColor backgroundColor: UIColor = .clear,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let backgroundTexture else { return }

        drawCurvePointsOnDrawingTexture(
            points: drawingCurveIterator.latestCurvePoints,
            with: commandBuffer
        )

        drawDrawingTextureWithBackgroundTexture(
            backgroundTexture: backgroundTexture,
            backgroundColor: backgroundColor,
            shouldUpdateSelectedTexture: drawingCurveIterator.isDrawingFinished,
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
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawTexture(
            texture: backgroundTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: backgroundColor,
            on: resultTexture,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: drawingTexture,
            into: resultTexture,
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
