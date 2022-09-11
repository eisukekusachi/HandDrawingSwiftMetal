//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import MetalKit
class Canvas: MTKView {
    var tool: Int = 0
    var brushDiameter: Float = 2.0
    var eraserDiameter: Float = 32.0
    private (set) var drawingTexture: MTLTexture?
    private var stroke: Stroke?
    private var nBrushRgb: (Float, Float, Float) = (0.0, 0.0, 0.0)
    private var nBrushAlpha: Float = 1.0
    private var nEraserAlpha: Float = 1.0
    private var textureSize: CGSize = .zero
    private var ratioOfScreenToTexture: CGFloat = 1.0
    // MetalKit
    private var commandQueue: MTLCommandQueue!
    private var displayTexture: MTLTexture?
    private var grayscaleTexture: MTLTexture?
    private var currentTexture: MTLTexture?
    private var tmpTexture: MTLTexture?
    private var psDrawGrayPointsMaxOneOne: MTLRenderPipelineState?
    private var psDrawTexture: MTLRenderPipelineState?
    private var psColorizeGrayscaleTexture: MTLComputePipelineState?
    private var psEraser: MTLRenderPipelineState?
    private var cpMerge: MTLComputePipelineState?
    private var cpFill: MTLComputePipelineState?
    private var cpCopy: MTLComputePipelineState?
    private var refreshMTKViewFlag: Bool = false
    private var runOnce: Bool = false
    // MARK: - Inialize
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        self.delegate = self
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        initializePipelines()
    }
    private func initializePipelines() {
        psDrawGrayPointsMaxOneOne = device?.maxOneOneRenderPipelineState("vDrawGrayPoints", "fDrawGrayPoints")
        psDrawTexture = device?.oneOneminussrcalphaRenderPipelineState("vDrawTexture", "fDrawTexture")
        psEraser = device?.zeroOneminussrcalphaRenderPipelineState("vDrawTexture", "fDrawTexture")
        psColorizeGrayscaleTexture = device?.computePipielineState("cColorizeGrayscaleTexture")
        cpFill = device?.computePipielineState("cFill")
        cpMerge = device?.computePipielineState("cMerge")
        cpCopy = device?.computePipielineState("cCopy")
    }
    private func initializeTexture(_ textureSize: CGSize) {
        self.textureSize = textureSize
        ratioOfScreenToTexture = textureSize.height / frame.height
        grayscaleTexture = device?.makeTexture(textureSize)
        drawingTexture = device?.makeTexture(textureSize)
        currentTexture = device?.makeTexture(textureSize)
        displayTexture = device?.makeTexture(textureSize)
        tmpTexture = device?.makeTexture(textureSize)
        commandQueue?.makeCommandBuffer()?
            .clear(cpFill, [drawingTexture, currentTexture, tmpTexture, displayTexture])
            .fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
            .commit()
    }
    override func layoutSubviews() {
        if !runOnce, let drawableSize = currentDrawable?.texture.size {
            runOnce = true
            initializeTexture(drawableSize)
            refreshCanvas()
        }
    }
    // MARK: - Touch handling functions
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if stroke == nil {
            stroke = Stroke()
            stroke?.touchType = event?.allTouches?.first?.type
        }
        guard let screenPointAndPressure = event?.allTouches?.first?.getPointAndPressure(self) else { return }
        stroke?.append(pointInScreen: screenPointAndPressure.0,
                       pressureValue: getOptimizedPressureValue(screenPointAndPressure.1),
                       ratioOfScreenToTexture: ratioOfScreenToTexture)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let screenPointAndPressure = event?.allTouches?.first?.getPointAndPressure(self) else { return }
        stroke?.append(pointInScreen: screenPointAndPressure.0,
                       pressureValue: getOptimizedPressureValue(screenPointAndPressure.1),
                       ratioOfScreenToTexture: ratioOfScreenToTexture)
        stroke?.makeCurve()
        if let curveWithShade = stroke?.latestCurveWithShade() {
            drawPoints(nVertices: curveWithShade.points.vertexCoordinate(textureSize),
                       nTransparencyValues: curveWithShade.values,
                       on: drawingTexture)
            refreshCanvas()
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let screenPointAndPressure = event?.allTouches?.first?.getPointAndPressure(self) else { return }
        stroke?.append(pointInScreen: screenPointAndPressure.0,
                       pressureValue: getOptimizedPressureValue(screenPointAndPressure.1),
                       ratioOfScreenToTexture: ratioOfScreenToTexture,
                       atTouchesEnded: true)
        stroke?.makeCurve()
        if let curveWithShade = stroke?.latestCurveWithShade() {
            drawPoints(nVertices: curveWithShade.points.vertexCoordinate(textureSize),
                       nTransparencyValues: curveWithShade.values,
                       on: drawingTexture)
            mergeDrawingTextureToCurrentTexture()
            refreshCanvas()
        }
        stroke = nil
    }
    // MARK: - Methods for drawing
    func drawPoints(nVertices: [CGPoint],
                    nTransparencyValues: [CGFloat]? = nil,
                    nRgb: (Float, Float, Float)? = nil,
                    nAlpha: Float? = nil,
                    diameter: Float? = nil,
                    maxBlendingGrayscaleTexture maxGrayScaleTexture: MTLTexture? = nil,
                    on resultTexture: MTLTexture?) {
        if nVertices.count == 0 { return }
        let maxBlendingGrayscaleTexture = maxGrayScaleTexture != nil ? maxGrayScaleTexture : grayscaleTexture
        commandQueue?.makeCommandBuffer()?
            .drawGrayPoints(psDrawGrayPointsMaxOneOne,
                            nVertices: nVertices,
                            nTransparencyValues: nTransparencyValues,
                            nAlpha: nAlpha ?? (tool == 0 ? nBrushAlpha : nEraserAlpha),
                            diameter: diameter ?? (tool == 0 ? brushDiameter : eraserDiameter),
                            on: maxBlendingGrayscaleTexture)
            .colorize(psColorizeGrayscaleTexture,
                      grayscaleTexture: maxBlendingGrayscaleTexture,
                      nRgb: nRgb ?? (tool == 0 ? nBrushRgb : (0, 0, 0)),
                      to: resultTexture)
            .commit()
    }
    func mergeDrawingTextureToCurrentTexture() {
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        if tool == 0 {
            commandBuffer
                .merge(cpMerge, drawingTexture, to: currentTexture)
        } else {
            commandBuffer
                .copy(cpCopy, currentTexture, to: tmpTexture)
                .drawTexture(psEraser, drawingTexture, to: tmpTexture, flipY: true)
                .copy(cpCopy, tmpTexture, to: currentTexture)
        }
        commandBuffer
            .clear(cpFill, drawingTexture)
            .fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
        commandBuffer.commit()
    }
    func refreshCanvas() {
        refreshDisplayTexture()
        refreshMTKView()
    }
    func clearAllTextures() {
        commandQueue?.makeCommandBuffer()?
            .clear(cpFill, [drawingTexture, currentTexture])
            .fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
            .commit()
    }
    private func refreshDisplayTexture() {
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer.fill(cpFill, nRgb: (1.0, 1.0, 1.0), to: displayTexture)
        if tool == 0 {
            commandBuffer
                .merge(cpMerge, [currentTexture, drawingTexture], to: displayTexture)
        } else {
            commandBuffer
                .copy(cpCopy, currentTexture, to: tmpTexture)
                .drawTexture(psEraser, drawingTexture, to: tmpTexture, flipY: true)
                .merge(cpMerge, tmpTexture, to: displayTexture)
        }
        commandBuffer.commit()
    }
    private func refreshMTKView() {
        refreshMTKViewFlag = true
    }
    private func getOptimizedPressureValue(_ pressure: CGFloat) -> CGFloat {
        let amplifier = 3.0
        let t = min(pressure * amplifier, 1.0)
        return t * t * (3 - 2 * t)
    }
}
extension Canvas: MTKViewDelegate {
    func draw(in view: MTKView) {
        if !refreshMTKViewFlag { return } else { refreshMTKViewFlag = false }
        guard   let drawable = view.currentDrawable,
                let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer.drawTexture(psDrawTexture, displayTexture, to: drawable.texture)
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
