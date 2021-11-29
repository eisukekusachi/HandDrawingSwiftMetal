//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
class Drawing {
    private (set) var curvePoints: [CGPoint] = []
    private (set) var curveForceValueArray: [CGFloat] = []
    private (set) var textureSize: CGSize = .zero
    private var touchPointsOnScreen: [CGPoint] = []
    private var forceValueArray: [CGFloat] = []
    private var smoothPoints: [CGPoint] = []
    private var smoothForceValueArray: [CGFloat] = []
    private var processedPointIndex: Int = 0
    private var ratioOfScreenToTexture: CGFloat = 1.0
    func initalizeRatio(taxtureSize: CGSize, frameSize: CGSize) {
        self.textureSize = taxtureSize
        self.ratioOfScreenToTexture =  taxtureSize.height / frameSize.height
    }
    func readyForDrawing() {
        touchPointsOnScreen = []
        forceValueArray = []
        smoothPoints = []
        smoothForceValueArray = []
        processedPointIndex = 0
        clearCurvePoints()
    }
    func appendTouchPoint(allTouches: Set<UITouch>?, view: UIView) {
        guard let touch = allTouches?.first else { return }
        var force = 1.0
        if touch.maximumPossibleForce != 0.0 {
            let amplifier: CGFloat = 4.0
            let offset: CGFloat = 0.1
            let t = max(0.0, min((touch.force / touch.maximumPossibleForce) * amplifier - offset, 1.0))
            force = t * t * (3 - 2 * t)
        }
        touchPointsOnScreen.append(touch.location(in: view))
        forceValueArray.append(force)
    }
    func makeCurvePoints() {
        makeSmoothPoints()
        makeBezierCurvePoints()
    }
    func makeSmoothPoints() {
        let ratio: [CGFloat] = [0.5]
        while processedPointIndex < touchPointsOnScreen.count - 1 {
            let point0 = touchPointsOnScreen[processedPointIndex + 0].multiply(ratioOfScreenToTexture)
            let point1 = touchPointsOnScreen[processedPointIndex + 1].multiply(ratioOfScreenToTexture)
            let force0 = forceValueArray[processedPointIndex + 0]
            let force1 = forceValueArray[processedPointIndex + 1]
            self.smoothPoints.append(contentsOf: [point0, point1].splite(ratio: ratio))
            self.smoothForceValueArray.append(contentsOf: [force0, force1].splite(ratio: ratio))
            processedPointIndex += 1
        }
    }
    func makeBezierCurvePoints() {
        while smoothPoints.count > 3 {
            let bezierCurvePoints = Interpolation.bezierCurve(a: smoothPoints[0], b: smoothPoints[1], c: smoothPoints[2], d: smoothPoints[3])
            curvePoints.append(contentsOf: bezierCurvePoints)
            curveForceValueArray.append(contentsOf: Interpolation.lerp(v0: smoothForceValueArray[1],
                                                                       v1: smoothForceValueArray[2],
                                                                       num: bezierCurvePoints.count))
            smoothPoints.remove(at: 0)
            smoothForceValueArray.remove(at: 0)
        }
    }
    func clearCurvePoints() {
        curvePoints = []
        curveForceValueArray = []
    }
    func getVertexCurvePoints() -> [CGPoint] {
        return curvePoints.vertexCoordinate(textureSize)
    }
}
