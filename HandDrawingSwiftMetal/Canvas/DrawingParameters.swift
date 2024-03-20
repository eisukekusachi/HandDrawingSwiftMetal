//
//  DrawingParameters.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit
import Combine

final class DrawingParameters {

    let diameterSubject = CurrentValueSubject<Float, Never>(1.0)

    let drawingToolSubject = CurrentValueSubject<DrawingToolType, Never>(.brush)

    let backgroundColorSubject = CurrentValueSubject<UIColor, Never>(.white)

    let matrixSubject = CurrentValueSubject<CGAffineTransform, Never>(.identity)

    let textureSizeSubject = CurrentValueSubject<CGSize, Never>(.zero)

    let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(false)

    let clearUndoSubject = PassthroughSubject<Void, Never>()

    let mergeLayersToRootTextureSubject = PassthroughSubject<Void, Never>()

    let setNeedsDisplaySubject = PassthroughSubject<Void, Never>()

    /// An instance for managing texture layers
    let layerManager = LayerManager()

    var frameSize: CGSize = .zero {
        didSet {
            layerManager.frameSize = frameSize
        }
    }

    /// A protocol for managing drawing
    private (set) var drawing: Drawing?

    private (set) var brushColor: UIColor
    private (set) var eraserAlpha: Int
    private (set) var brushDiameter: Int
    private (set) var eraserDiameter: Int

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var blurSize: Float = BlurredDotSize.initBlurSize

    private var cancellables = Set<AnyCancellable>()

    init(
        brushDiameter: Int = 8,
        eraserDiameter: Int = 44,
        brushColor: UIColor = .black.withAlphaComponent(0.75),
        eraserAlpha: Int = 150,
        backgroundColor: UIColor = .white
    ) {
        self.brushDiameter = brushDiameter
        self.eraserDiameter = eraserDiameter
        self.brushColor = brushColor
        self.eraserAlpha = eraserAlpha

        setBackgroundColor(backgroundColor)

        drawingToolSubject
            .sink { [weak self] tool in
                guard let `self` else { return }
                drawing = tool == .brush ? layerManager.drawingBrush : layerManager.drawingEraser
            }
            .store(in: &cancellables)

        layerManager.mergeLayersToRootTextureSubject
            .sink { [weak self] in
                guard let `self` else { return }
                mergeLayersToRootTextureSubject.send()
            }
            .store(in: &cancellables)
    }

}

extension DrawingParameters {

    func setDrawingTool(_ tool: DrawingToolType) {

        switch tool {
        case .brush:
            diameterSubject.send(DrawingToolBrush.diameterFloatValue(brushDiameter))
        case .eraser:
            diameterSubject.send(DrawingToolEraser.diameterFloatValue(eraserDiameter))
        }

        drawingToolSubject.send(tool)
    }

    func setBrushColor(_ color: UIColor) {
        brushColor = color
    }
    func setEraserAlpha(_ alpha: Int) {
        eraserAlpha = alpha
    }

}

extension DrawingParameters {

    var brushDotSize: BlurredDotSize {
        BlurredDotSize(diameter: brushDiameter, blurSize: blurSize)
    }
    var eraserDotSize: BlurredDotSize {
        BlurredDotSize(diameter: eraserDiameter, blurSize: blurSize)
    }

    @objc func handleDiameterSlider(_ sender: UISlider) {
        if drawingToolSubject.value == .brush {
            setBrushDiameter(sender.value)

        } else if drawingToolSubject.value == .eraser {
            setEraserDiameter(sender.value)
        }
    }

    func setBrushDiameter(_ value: Float) {
        brushDiameter = DrawingToolBrush.diameterIntValue(value)
    }
    func setEraserDiameter(_ value: Float) {
        eraserDiameter = DrawingToolEraser.diameterIntValue(value)
    }

    func setBrushDiameter(_ value: Int) {
        brushDiameter = value
    }
    func setEraserDiameter(_ value: Int) {
        eraserDiameter = value
    }

}

extension DrawingParameters {

    func setBackgroundColor(_ color: UIColor) {
        self.backgroundColorSubject.send(color)
    }
    
}

extension DrawingParameters {

    func initLayers(textureSize: CGSize) {
        layerManager.reset(textureSize)
    }

    func mergeAllLayers(to dstTexture: MTLTexture?,
                        _ commandBuffer: MTLCommandBuffer) {
        guard   let dstTexture,
                let selectedTexture = layerManager.selectedTexture,
                let selectedTextures = drawing?.getDrawingTextures(selectedTexture)
        else { return }

        layerManager.mergeAllTextures(selectedTextures: selectedTextures.compactMap { $0 },
                                      selectedAlpha: layerManager.selectedLayerAlpha,
                                      backgroundColor: backgroundColorSubject.value.rgb,
                                      to: dstTexture,
                                      commandBuffer)
    }

}
