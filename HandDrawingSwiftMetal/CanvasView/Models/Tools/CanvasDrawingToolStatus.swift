//
//  CanvasDrawingToolStatus.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit
import Combine

final class CanvasDrawingToolStatus {

    var drawingTool: CanvasDrawingToolType {
        drawingToolSubject.value
    }

    var backgroundColor: UIColor {
        backgroundColorSubject.value
    }

    var drawingToolPublisher: AnyPublisher<CanvasDrawingToolType, Never> {
        drawingToolSubject.eraseToAnyPublisher()
    }
    var diameterPublisher: AnyPublisher<Float, Never> {
        diameterSubject.eraseToAnyPublisher()
    }
    var backgroundColorPublisher: AnyPublisher<UIColor, Never> {
        backgroundColorSubject.eraseToAnyPublisher()
    }

    private let drawingToolSubject = CurrentValueSubject<CanvasDrawingToolType, Never>(.brush)

    private let diameterSubject = CurrentValueSubject<Float, Never>(1.0)

    private let backgroundColorSubject = CurrentValueSubject<UIColor, Never>(.white)

    private(set) var brushColor: UIColor
    private(set) var eraserAlpha: Int
    private(set) var brushDiameter: Int
    private(set) var eraserDiameter: Int

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
    }

}

extension CanvasDrawingToolStatus {

    func setDrawingTool(_ tool: CanvasDrawingToolType) {

        switch drawingTool {
        case .brush: diameterSubject.send(CanvasBrushDrawingTool.diameterFloatValue(brushDiameter))
        case .eraser: diameterSubject.send(CanvasEraserDrawingTool.diameterFloatValue(eraserDiameter))
        }

        drawingToolSubject.send(tool)
    }

}

extension CanvasDrawingToolStatus {

    @objc func handleDiameterSlider(_ sender: UISlider) {
        switch drawingTool {
        case .brush: setBrushDiameter(sender.value)
        case .eraser: setEraserDiameter(sender.value)
        }
    }

}

extension CanvasDrawingToolStatus {

    func setBrushColor(_ color: UIColor) {
        brushColor = color
    }
    func setEraserAlpha(_ alpha: Int) {
        eraserAlpha = alpha
    }

}

extension CanvasDrawingToolStatus {
    var diameter: Int {
        switch drawingTool {
        case .brush: brushDiameter
        case .eraser: eraserDiameter
        }
    }
    func setBrushDiameter(_ value: Float) {
        brushDiameter = CanvasBrushDrawingTool.diameterIntValue(value)
    }
    func setEraserDiameter(_ value: Float) {
        eraserDiameter = CanvasEraserDrawingTool.diameterIntValue(value)
    }

    func setBrushDiameter(_ value: Int) {
        brushDiameter = value
    }
    func setEraserDiameter(_ value: Int) {
        eraserDiameter = value
    }

}

extension CanvasDrawingToolStatus {

    func setBackgroundColor(_ color: UIColor) {
        self.backgroundColorSubject.send(color)
    }

}
