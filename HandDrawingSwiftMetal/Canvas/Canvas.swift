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
    private var brushNRgb: (Float, Float, Float) = (0.0, 0.0, 0.0)
    private var brushNAlpha: Float = 1.0
    private var eraserNAlpha: Float = 1.0
    private var textureSize: CGSize = .zero
    private var ratioOfScreenToTexture: CGFloat = 1.0
    private var touchObject = DrawingObject()
    private var smoothPointsObject = DrawingObject()
    private var smoothPointsIndex: Int = 0
    private var curveIndex: Int = 0
    private var firstCurveHasBeenDrawnFlag: Bool = false
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
        prepareForNewCurve()
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
            referesh()
        }
    }
    // MARK: Events
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let screenPointWithValue = getTouchPointWithForceValue(touch: event?.allTouches?.first, view: self) else { return }
        touchObject.append(point: screenPointWithValue.0, value: screenPointWithValue.1)
        smoothPointsObject.append(object: touchObject.getFirst().multiplyPoints(by: ratioOfScreenToTexture))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let screenPointWithValue = getTouchPointWithForceValue(touch: event?.allTouches?.first, view: self) else { return }
        if screenPointWithValue.0.distance(touchObject.points.last) > 1.4 {
            touchObject.append(point: screenPointWithValue.0, value: screenPointWithValue.1)
        }
        smoothPointsObject.append(object: touchObject.smoothed(processedIndex: &smoothPointsIndex).multiplyPoints(by: ratioOfScreenToTexture))
        var curveObject = DrawingObject()
        if !firstCurveHasBeenDrawnFlag && smoothPointsObject.pointCount >= 3 {
            firstCurveHasBeenDrawnFlag = true
            curveObject.append(object: smoothPointsObject.curvedAtFirst())
        }
        curveObject.append(object: smoothPointsObject.curved(processedIndex: &curveIndex))
        drawPoints(vertices: curveObject.points.vertexCoordinate(textureSize),
                   nTransparencyValues: curveObject.values,
                   on: drawingTexture)
        referesh()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let screenPointWithValue = getTouchPointWithForceValue(touch: event?.allTouches?.first, view: self) else { return }
        if screenPointWithValue.0.distance(touchObject.points.last) > 1.4 {
            touchObject.append(point: screenPointWithValue.0, value: screenPointWithValue.1)
        }
        smoothPointsObject.append(object: touchObject.smoothed(processedIndex: &smoothPointsIndex).multiplyPoints(by: ratioOfScreenToTexture))
        smoothPointsObject.append(object: touchObject.getLast().multiplyPoints(by: ratioOfScreenToTexture))
        var curveObject = DrawingObject()
        curveObject.append(object: smoothPointsObject.curved(processedIndex: &curveIndex))
        curveObject.append(object: smoothPointsObject.curvedAtEnd())
        // If draw a dot, set the value to 1.0.
        if curveObject.pointCount == 1 {
            curveObject.setValue(index: 0, value: 1.0)
        }
        drawPoints(vertices: curveObject.points.vertexCoordinate(textureSize),
                   nTransparencyValues: curveObject.values,
                   on: drawingTexture)
        mergeDrawingTextureToCurrentTexture()
        referesh()
        prepareForNewCurve()
    }
    private func getTouchPointWithForceValue(touch: UITouch?, view: UIView) -> (CGPoint, CGFloat)? {
        guard let touch = touch else { return nil }
        var force: CGFloat = 1.0
        if touch.maximumPossibleForce != 0.0 {
            let amplifier: CGFloat = 4.0
            let offset: CGFloat = 0.1
            let t = max(0.0, min((touch.force / touch.maximumPossibleForce) * amplifier - offset, 1.0))
            force = t * t * (3 - 2 * t)
        }
        return (touch.location(in: view), force)
    }
    func drawPoints(vertices: [CGPoint],
                    nTransparencyValues: [CGFloat]? = nil,
                    nRgb: (Float, Float, Float)? = nil,
                    nAlpha: Float? = nil,
                    diameter: Float? = nil,
                    maxBlendingGrayscaleTexture: MTLTexture? = nil,
                    on texture: MTLTexture?) {
        if vertices.count == 0 { return }
        var maxBlendingGrayscaleTexture = maxBlendingGrayscaleTexture
        if maxBlendingGrayscaleTexture == nil { maxBlendingGrayscaleTexture = grayscaleTexture }
        commandQueue?.makeCommandBuffer()?
            .drawGrayPoints(psDrawGrayPointsMaxOneOne,
                            vertices: vertices,
                            nTransparencyValues: nTransparencyValues,
                            nAlpha: nAlpha ?? (tool == 0 ? brushNAlpha : eraserNAlpha),
                            diameter: diameter ?? (tool == 0 ? brushDiameter : eraserDiameter),
                            on: maxBlendingGrayscaleTexture)
            .colorize(psColorizeGrayscaleTexture,
                      grayscaleTexture: maxBlendingGrayscaleTexture,
                      nRgb: nRgb ?? (tool == 0 ? brushNRgb : (0, 0, 0)),
                      to: texture)
            .commit()
    }
    func clearAllTextures() {
        commandQueue?.makeCommandBuffer()?
            .clear(cpFill, [drawingTexture, currentTexture])
            .fill(cpFill, nRgb: (0.0, 0.0, 0.0), to: grayscaleTexture)
            .commit()
    }
    func referesh() {
        refereshDisplayTexture()
        refreshMTKView()
    }
    private func refereshDisplayTexture() {
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
    private func mergeDrawingTextureToCurrentTexture() {
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
    private func refreshMTKView() {
        refreshMTKViewFlag = true
    }
    private func prepareForNewCurve() {
        smoothPointsIndex = 0
        curveIndex = 0
        touchObject.removeAll()
        smoothPointsObject.removeAll()
        firstCurveHasBeenDrawnFlag = false
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
