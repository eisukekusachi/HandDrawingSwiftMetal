//
//  CGAffineTransformExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/31.
//

import Foundation

extension CGAffineTransform {
    func getInvertedValue(scale: CGFloat) -> Self {
        var matrix = self.getInvertedValue(flipY: true)
        matrix.tx *= scale
        matrix.ty *= scale

        return matrix
    }
    func getInvertedValue(flipY: Bool = false) -> Self {

        let scale = sqrt((self.a * self.a + self.c * self.c))
        let radian = atan2(self.b, self.a)
        let iScale: CGFloat = 1.0 / scale
        let a: CGFloat = cos(radian) * iScale
        let b: CGFloat = sin(radian) * iScale
        let c: CGFloat = -sin(radian) * iScale
        let d: CGFloat = cos(radian) * iScale
        let matrixTx: CGFloat = -self.tx
        var matrixTy: CGFloat = -self.ty
        if flipY {
            matrixTy *= -1.0
        }
        let tx: CGFloat = (matrixTx * a + matrixTy * c)
        let ty: CGFloat = (matrixTx * b + matrixTy * d)

        return CGAffineTransform.init(a: a, b: b,
                                      c: c, d: d,
                                      tx: tx, ty: ty)
    }

    // Generate a matrix from a center point and two points
    static func makeMatrix(center: CGPoint,
                           pointsA: (CGPoint?, CGPoint?),
                           pointsB: (CGPoint?, CGPoint?),
                           counterRotate: Bool = false,
                           flipY: Bool = false) -> Self? {
        guard   let pt1: CGPoint = pointsA.0,
                let pt2: CGPoint = pointsB.0,
                let pt3: CGPoint = pointsA.1,
                let pt4: CGPoint = pointsB.1 else { return nil }

        let layerX = center.x
        let layerY = center.y
        let x1 = pt1.x - layerX
        let y1 = pt1.y - layerY
        let x2 = pt2.x - layerX
        let y2 = pt2.y - layerY
        let x3 = pt3.x - layerX
        let y3 = pt3.y - layerY
        let x4 = pt4.x - layerX
        let y4 = pt4.y - layerY

        let distance = (y1 - y2) * (y1 - y2) + (x1 - x2) * (x1 - x2)
        if distance < 0.1 {
            return nil
        }

        let cos = ((y1 - y2) * (y3 - y4) + (x1 - x2) * (x3 - x4)) / distance
        let sin = ((y1 - y2) * (x3 - x4) - (x1 - x2) * (y3 - y4)) / distance
        let posx = ((y1 * x2 - x1 * y2) * (y4 - y3) - (x1 * x2 + y1 * y2) * (x3 + x4) + x3 * (y2 * y2 + x2 * x2) + x4 * (y1 * y1 + x1 * x1)) / distance
        let posy = ((x1 * x2 + y1 * y2) * (-y4 - y3) + (y1 * x2 - x1 * y2) * (x3 - x4) + y3 * (y2 * y2 + x2 * x2) + y4 * (y1 * y1 + x1 * x1)) / distance
        let a = cos
        let b = counterRotate == false ? -sin :  sin
        let c = counterRotate == false ?  sin : -sin
        let d = cos
        let tx = posx
        var ty = posy
        if flipY {
            ty *= -1.0
        }
        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    static func getInitialMatrix(scale: CGFloat, position: CGPoint) -> Self {
        CGAffineTransform(a: scale, b: 0.0,
                          c: 0.0, d: scale,
                          tx: position.x, ty: position.y)
    }
}
