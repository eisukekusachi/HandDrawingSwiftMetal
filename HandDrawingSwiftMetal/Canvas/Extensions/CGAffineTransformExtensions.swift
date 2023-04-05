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
}
