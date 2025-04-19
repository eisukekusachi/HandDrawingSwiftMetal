//
//  DrawingEraserTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/19.
//

import UIKit

final class DrawingEraserTool: ObservableObject, DrawingToolProtocol {

    @Published var diameter: Int = 0

    @Published var alpha: Int = 0 {
        didSet {
            let clamped = max(0, min(alpha, 255))
            if alpha != clamped {
                alpha = clamped
            }
        }
    }

}

extension DrawingEraserTool {

    func setData(alpha: Int, diameter: Int) {
        self.alpha = alpha
        self.diameter = diameter
    }

    func sliderValue() -> Float {
        DrawingEraserTool.diameterFloatValue(diameter)
    }

    func setDiameter(_ value: Float) {
        diameter = DrawingEraserTool.diameterIntValue(value)
    }
    func setDiameter(_ value: Int) {
        diameter = value
    }

}

extension DrawingEraserTool {
    static private let minDiameter: Int = 1
    static private let maxDiameter: Int = 64

    static private let initEraserSize: Int = 8

    static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
