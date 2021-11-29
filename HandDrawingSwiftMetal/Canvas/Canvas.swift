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
    private var brushNRgb: (Float, Float, Float) = (0.0, 0.0, 0.0)
    private var brushNAlpha: Float = 1.0
    private var eraserNAlpha: Float = 1.0
    private var drawing = Drawing()
    private var commandQueue: MTLCommandQueue!
    private var displayTexture: MTLTexture?
    private var grayscaleTexture: MTLTexture?
    private var currentTexture: MTLTexture?
    private var drawingTexture: MTLTexture?
    private var tmpTexture: MTLTexture?
    private var psDrawGrayPointsMaxOneOne: MTLRenderPipelineState?
    private var psDrawTexture: MTLRenderPipelineState?
    private var psColorizeGrayscaleTexture: MTLComputePipelineState?
    private var psEraser: MTLRenderPipelineState?
    private var cpMerge: MTLComputePipelineState?
    private var cpFill: MTLComputePipelineState?
    private var cpCopy: MTLComputePipelineState?
    private var refreshMTKViewFlag: Bool = false
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
        drawing.readyForDrawing()
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
    func initializeRequiredTextures(_ textureSize: CGSize) {
        grayscaleTexture = device?.makeTexture(textureSize)
        drawingTexture = device?.makeTexture(textureSize)
        currentTexture = device?.makeTexture(textureSize)
        displayTexture = device?.makeTexture(textureSize)
        tmpTexture = device?.makeTexture(textureSize)
        if let commandBuffer = commandQueue?.makeCommandBuffer() {
            commandBuffer.clear(cpFill, [drawingTexture, currentTexture, tmpTexture, displayTexture])
            commandBuffer.fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
            commandBuffer.commit()
        }
        drawing.initalizeRatio(taxtureSize: textureSize, frameSize: frame.size)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawing.appendTouchPoint(allTouches: event?.allTouches, view: self)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawing.appendTouchPoint(allTouches: event?.allTouches, view: self)
        drawing.makeCurvePoints()
        drawCurve(vertices: drawing.getVertexCurvePoints(), transparencyData: drawing.curveForceValueArray, on: drawingTexture)
        drawing.clearCurvePoints()
        refereshDisplayTexture()
        refreshMTKView()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawing.appendTouchPoint(allTouches: event?.allTouches, view: self)
        drawing.makeCurvePoints()
        drawCurve(vertices: drawing.getVertexCurvePoints(), transparencyData: drawing.curveForceValueArray, on: drawingTexture)
        drawing.clearCurvePoints()
        mergeDrawingTextureToCurrentTexture()
        refereshDisplayTexture()
        refreshMTKView()
        if let eventTouches = event?.allTouches, eventTouches.count == touches.count {
            clearDrawingTextures()
            drawing.readyForDrawing()
        }
    }
    func drawCurve(vertices: [CGPoint], transparencyData: [CGFloat], on texture: MTLTexture?) {
        if vertices.count == 0 { return }
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer.drawGrayPoints(psDrawGrayPointsMaxOneOne,
                                     vertices: vertices,
                                     transparencyData: transparencyData,
                                     diameter: tool == 0 ? brushDiameter : eraserDiameter,
                                     nAlpha: tool == 0 ? brushNAlpha : eraserNAlpha,
                                     on: grayscaleTexture)
        commandBuffer.colorize(psColorizeGrayscaleTexture,
                               grayscaleTexture: grayscaleTexture,
                               nRgb: tool == 0 ? brushNRgb : (0, 0, 0),
                               to: texture)
        commandBuffer.commit()
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
        commandBuffer.clear(cpFill, drawingTexture)
        commandBuffer.commit()
    }
    func refereshDisplayTexture() {
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer.fill(cpFill, nRgb: (1.0, 1.0, 1.0), to: displayTexture)
        if tool == 0 {
            commandBuffer
                .merge(cpMerge, [drawingTexture, currentTexture], to: displayTexture)
        } else {
            commandBuffer
                .copy(cpCopy, currentTexture, to: tmpTexture)
                .drawTexture(psEraser, drawingTexture, to: tmpTexture, flipY: true)
                .merge(cpMerge, tmpTexture, to: displayTexture)
        }
        commandBuffer.commit()
    }
    func refreshMTKView() {
        refreshMTKViewFlag = true
    }
    func clearCanvas() {
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer
            .clear(cpFill, [drawingTexture, currentTexture])
            .fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
        commandBuffer.commit()
    }
    func clearDrawingTextures() {
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        commandBuffer
            .clear(cpFill, drawingTexture)
            .fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
        commandBuffer.commit()
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
