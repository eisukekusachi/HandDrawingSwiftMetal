//
//  DrawingBrushToolState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/19.
//

import UIKit

final class DrawingBrushToolState: ObservableObject, DrawingToolProtocol {

    @Published var diameter: Int = 0

    @Published var color: UIColor = .clear

}

extension DrawingBrushToolState {

    func sliderValue() -> Float {
        DrawingBrushToolState.diameterFloatValue(diameter)
    }

    func setDiameter(_ value: Float) {
        diameter = DrawingBrushToolState.diameterIntValue(value)
    }
    func setDiameter(_ value: Int) {
        diameter = value
    }

}

extension DrawingBrushToolState {
    static private let minDiameter: Int = 1
    static private let maxDiameter: Int = 64

    static private let initBrushSize: Int = 8

    static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
