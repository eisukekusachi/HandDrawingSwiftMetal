//
//  MatrixManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/30.
//

import UIKit

typealias TransformationData = (
    pointsA: (CGPoint?, CGPoint?),
    pointsB: (CGPoint?, CGPoint?)
)

protocol Transforming {
    
    var initialScale: CGFloat { get }
    var initialPosition: CGPoint { get }
    var storedMatrix: CGAffineTransform { get set }
    
    func setInitialValue(scale: CGFloat, position: CGPoint)
    
    func update(viewTouches: [Int: [Point]], viewSize: CGSize) -> CGAffineTransform?
    func endTransforming(_ matrix: CGAffineTransform)
    
    func reset()
}

extension Transforming {
    func makeTransformationData(_ pointDictionary: [Int: [Point]]) -> TransformationData? {
        
        if pointDictionary.count == 2 {
            
            let pointsA = pointDictionary.first
            let pointsB = pointDictionary.last
            
            return TransformationData(pointsA: (pointsA?.first?.location, pointsA?.last?.location),
                                      pointsB: (pointsB?.first?.location, pointsB?.last?.location))
        }
        return nil
    }
    
    func makeMatrix(_ pointDictionary: [Int: [Point]], viweSize: CGSize) -> CGAffineTransform? {
        
        guard let transformationData = makeTransformationData(pointDictionary),
              let newMatrix = makeMatrix(center: Calc.getCenter(viweSize),
                                         pointsA: transformationData.pointsA,
                                         pointsB: transformationData.pointsB,
                                         counterRotate: true,
                                         flipY: true) else {
            return nil
        }
        
        return newMatrix
    }
    func makeMatrix(center: CGPoint,
                    pointsA: (CGPoint?, CGPoint?),
                    pointsB: (CGPoint?, CGPoint?),
                    counterRotate: Bool = false,
                    flipY: Bool = false) -> CGAffineTransform? {
        
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
        
        let cos = ((y1-y2) * (y3-y4) + (x1-x2) * (x3-x4)) / distance
        let sin = ((y1-y2) * (x3-x4) - (x1-x2) * (y3-y4)) / distance
        let posx = ((y1*x2 - x1*y2) * (y4-y3) - (x1*x2 + y1*y2) * (x3+x4) + x3 * (y2*y2 + x2*x2) + x4 * (y1*y1 + x1*x1)) / distance
        let posy = ((x1*x2 + y1*y2) * (-y4-y3) + (y1*x2 - x1*y2) * (x3-x4) + y3 * (y2*y2 + x2*x2) + y4 * (y1*y1 + x1*x1)) / distance
        let a = cos
        let b = counterRotate == false ? -sin :  sin
        let c = counterRotate == false ?  sin : -sin
        let d = cos
        let tx = posx
        var ty = posy
        if flipY {
            ty *= -1.0
        }
        return CGAffineTransform.init(a: a, b: b,
                                      c: c, d: d,
                                      tx: tx, ty: ty )
    }
}

class TransformingImpl: Transforming {
    
    var storedMatrix: CGAffineTransform = CGAffineTransform.identity
    
    var initialScale: CGFloat = 1.0
    var initialPosition: CGPoint = .zero
    
    func setInitialValue(scale: CGFloat, position: CGPoint) {
        
        self.initialScale = scale
        self.initialPosition = position
    }
    
    func update(viewTouches: [Int: [Point]], viewSize: CGSize) -> CGAffineTransform? {
        guard let data = makeTransformationData(viewTouches),
              let newMatrix = makeMatrix(center: Calc.getCenter(viewSize),
                                         pointsA: data.pointsA,
                                         pointsB: data.pointsB,
                                         counterRotate: true,
                                         flipY: true) else {
            return nil
        }
        return storedMatrix.concatenating(newMatrix)
    }
    func endTransforming(_ matrix: CGAffineTransform) {
        storedMatrix = matrix
    }
    
    func reset() {
        storedMatrix = CGAffineTransform(a: initialScale, b: 0.0,
                                         c: 0.0, d: initialScale,
                                         tx: initialPosition.x, ty: initialPosition.y)
    }
}
