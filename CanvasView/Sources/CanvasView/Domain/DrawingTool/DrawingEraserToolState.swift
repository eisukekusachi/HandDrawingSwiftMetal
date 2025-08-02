//
//  DrawingEraserToolState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/19.
//

import UIKit

public final class DrawingEraserToolState: ObservableObject, DrawingToolProtocol {

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

extension DrawingEraserToolState {

    func sliderValue() -> Float {
        DrawingEraserToolState.diameterFloatValue(diameter)
    }

    func setDiameter(_ value: Float) {
        diameter = DrawingEraserToolState.diameterIntValue(value)
    }
    func setDiameter(_ value: Int) {
        diameter = value
    }

}

public extension DrawingEraserToolState {
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
