//
//  CanvasBezierCurvePoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/10/19.
//

import Foundation

/// A struct that defines the points needed to create a first Bézier curve
struct CanvasFirstBezierCurvePoints {
    let previousPoint: GrayscaleDotPoint
    let startPoint: GrayscaleDotPoint
    let endPoint: GrayscaleDotPoint
}

/// A struct that defines the points needed to create a Bézier curve
struct CanvasIntermediateBezierCurvePoints {
    let previousPoint: GrayscaleDotPoint
    let startPoint: GrayscaleDotPoint
    let endPoint: GrayscaleDotPoint
    let nextPoint: GrayscaleDotPoint
}

/// A struct that defines the points needed to create a last Bézier curve
struct CanvasLastBezierCurvePoints {
    let previousPoint: GrayscaleDotPoint
    let startPoint: GrayscaleDotPoint
    let endPoint: GrayscaleDotPoint
}
