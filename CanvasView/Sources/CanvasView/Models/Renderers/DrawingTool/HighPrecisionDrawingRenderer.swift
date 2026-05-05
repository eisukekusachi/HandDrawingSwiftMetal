//
//  HighPrecisionDrawingRenderer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/05/05.
//

import Foundation

@MainActor
public protocol HighPrecisionDrawingRenderer: DrawingRenderer, HighPrecisionProtocol {}

@MainActor
public protocol HighPrecisionProtocol {

    /// Sets curve-space scale for the stroke about to begin
    func setStrokeCurveScale(_ scale: CGFloat)
}

public extension HighPrecisionProtocol {
    func clampedStrokeCurveScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 64)
    }
}
