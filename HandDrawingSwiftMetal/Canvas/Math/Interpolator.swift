//
//  Interpolation.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

private let handleMaxLengthRatio: CGFloat = 0.38
private let toRadian: CGFloat = (3.14 / 180.0)

enum Interpolator {
    static func firstCurve(previousPoint: TouchPoint,
                           startPoint: TouchPoint,
                           endPoint: TouchPoint,
                           addLastPoint: Bool = false) -> [TouchPoint] {
        var curve: [TouchPoint] = []

        let locations = Interpolator.firstCurve(pointA: previousPoint.location,
                                                pointB: startPoint.location,
                                                pointC: endPoint.location,
                                                addLastPoint: addLastPoint)
        let alphaArray = Interpolator.linear(begin: previousPoint.alpha,
                                             change: startPoint.alpha,
                                             duration: locations.count)
        
        for i in 0 ..< locations.count {
            curve.append(TouchPoint(location: locations[i],
                                    alpha: alphaArray[i]))
        }
        
        return curve
    }
    static func curve(previousPoint: TouchPoint,
                      startPoint: TouchPoint,
                      endPoint: TouchPoint,
                      nextPoint: TouchPoint) -> [TouchPoint] {
        var curve: [TouchPoint] = []

        let locations = Interpolator.curve(previousPoint: previousPoint.location,
                                           startPoint: startPoint.location,
                                           endPoint: endPoint.location,
                                           nextPoint: nextPoint.location)
        let alphaArray = Interpolator.linear(begin: startPoint.alpha,
                                             change: endPoint.alpha,
                                             duration: locations.count)
        
        for i in 0 ..< locations.count {
            curve.append(TouchPoint(location: locations[i],
                                    alpha: alphaArray[i]))
        }
        
        return curve
    }
    static func lastCurve(startPoint: TouchPoint,
                          endPoint: TouchPoint,
                          nextPoint: TouchPoint,
                          addLastPoint: Bool = false) -> [TouchPoint] {
        var curve: [TouchPoint] = []

        let locations = Interpolator.lastCurve(pointA: startPoint.location,
                                               pointB: endPoint.location,
                                               pointC: nextPoint.location,
                                               addLastPoint: addLastPoint)
        let alphaArray = Interpolator.linear(begin: endPoint.alpha,
                                             change: nextPoint.alpha,
                                             duration: locations.count)
        
        for i in 0 ..< locations.count {
            curve.append(TouchPoint(location: locations[i],
                                    alpha: alphaArray[i]))
        }
        
        return curve
    }
    
    private static func firstCurve(pointA: CGPoint,
                                   pointB: CGPoint,
                                   pointC: CGPoint,
                                   addLastPoint: Bool = false) -> [CGPoint] {
        
        let cbVector = CGVector(lhs: pointB, rhs: pointC)
        let baVector = CGVector(lhs: pointA, rhs: pointB)
        let abVector = CGVector(lhs: pointB, rhs: pointA)
        let cbaVector = CGVector(dx: cbVector.dx + baVector.dx, dy: cbVector.dy + baVector.dy)
        
        let adjustValue1 = Calc.getRadian(cbVector, Calc.getReversedVector(baVector)) / .pi
        let length1 = Calc.getLength(baVector) * handleMaxLengthRatio * max(0.0, adjustValue1)
        let cp1Vector = Calc.getResizedVector(cbaVector, length: length1)
        let cp1: CGPoint = CGPoint(x: cp1Vector.dx + pointB.x, y: cp1Vector.dy + pointB.y)
        
        let length0 = Calc.getLength(abVector) * handleMaxLengthRatio * max(0.0, adjustValue1)
        let cp0Vector = Calc.getResizedVector(abVector, length: length0)
        let cp0: CGPoint = CGPoint(x: cp0Vector.dx + pointA.x, y: cp0Vector.dy + pointA.y)
        
        let circumference: Int = Int(Calc.distance(pointA, to: cp0) +
                                     Calc.distance(cp0, to: cp1) +
                                     Calc.distance(cp1, to: pointB))
        
        return Interpolator.cubicCurve(movePoint: pointA,
                                       controlPoint1: cp0,
                                       controlPoint2: cp1,
                                       endPoint: pointB,
                                       totalPointNum: max(1, circumference),
                                       addLastPoint: addLastPoint)
    }
    static func curve(previousPoint: CGPoint,
                      startPoint: CGPoint,
                      endPoint: CGPoint,
                      nextPoint: CGPoint,
                      addLastPoint: Bool = false) -> [CGPoint] {
        
        let abVector = CGVector(lhs: startPoint, rhs: previousPoint)
        let bcVector = CGVector(lhs: endPoint, rhs: startPoint)
        let cdVector = CGVector(lhs: nextPoint, rhs: endPoint)
        let abcVector = CGVector(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy)
        let dcbVector = Calc.getReversedVector(CGVector(dx: bcVector.dx + cdVector.dx, dy: bcVector.dy + cdVector.dy))
        
        let adjustValue0 = Calc.getRadian(abVector, Calc.getReversedVector(bcVector)) / .pi
        let length0 = Calc.getLength(bcVector) * handleMaxLengthRatio * max(0.0, adjustValue0)
        let cp0Vector = Calc.getResizedVector(abcVector, length: length0)
        
        let adjustValue1 = Calc.getRadian(bcVector, Calc.getReversedVector(cdVector)) / .pi
        let length1 = Calc.getLength(bcVector) * handleMaxLengthRatio * max(0.0, adjustValue1)
        let cp1Vector = Calc.getResizedVector(dcbVector, length: length1)
        
        let cp0 = CGPoint(x: cp0Vector.dx + startPoint.x, y: cp0Vector.dy + startPoint.y)
        let cp1 = CGPoint(x: cp1Vector.dx + endPoint.x, y: cp1Vector.dy + endPoint.y)
        let circumference: Int = Int(Calc.distance(startPoint, to: cp0) +
                                     Calc.distance(cp0, to: cp1) +
                                     Calc.distance(cp1, to: endPoint))
        
        return Interpolator.cubicCurve(movePoint: startPoint,
                                       controlPoint1: cp0,
                                       controlPoint2: cp1,
                                       endPoint: endPoint,
                                       totalPointNum: max(1, circumference),
                                       addLastPoint: addLastPoint)
    }
    static func lastCurve(pointA: CGPoint,
                          pointB: CGPoint,
                          pointC: CGPoint,
                          addLastPoint: Bool = false) -> [CGPoint] {
        
        let abVector = CGVector(lhs: pointB, rhs: pointA)
        let bcVector = CGVector(lhs: pointC, rhs: pointB)
        let cbVector = CGVector(lhs: pointB, rhs: pointC)
        let abcVector = CGVector(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy)
        
        let adjustValue0 = Calc.getRadian(abVector, Calc.getReversedVector(bcVector)) / .pi
        let length0 = Calc.getLength(bcVector) * handleMaxLengthRatio * max(0.0, adjustValue0)
        let cp0Vector = Calc.getResizedVector(abcVector, length: length0)
        let cp0: CGPoint = CGPoint(x: cp0Vector.dx + pointB.x, y: cp0Vector.dy + pointB.y)
        
        let length1 = Calc.getLength(cbVector) * handleMaxLengthRatio * max(0.0, adjustValue0)
        let cp1Vector = Calc.getResizedVector(cbVector, length: length1)
        let cp1: CGPoint = CGPoint(x: cp1Vector.dx + pointC.x, y: cp1Vector.dy + pointC.y)
        
        let circumference: Int = Int(Calc.distance(pointB, to: cp0) +
                                     Calc.distance(cp0, to: cp1) +
                                     Calc.distance(cp1, to: pointC))
        
        return Interpolator.cubicCurve(movePoint: pointB,
                                       controlPoint1: cp0,
                                       controlPoint2: cp1,
                                       endPoint: pointC,
                                       totalPointNum: max(1, circumference),
                                       addLastPoint: addLastPoint)
    }
    
    static func cubicCurve(movePoint: CGPoint,
                           controlPoint1: CGPoint,
                           controlPoint2: CGPoint,
                           endPoint: CGPoint,
                           totalPointNum: Int,
                           addLastPoint: Bool = true) -> [CGPoint] {
        
        var result: [CGPoint] = []
        
        var t: Float = 0.0
        let step: Float = 1.0 / Float(totalPointNum)
        
        for _ in 0 ..< totalPointNum {
            
            let movex = movePoint.x * CGFloat(powf(1.0 - t, 3.0))
            let control1x = controlPoint1.x * CGFloat(3.0 * t * powf(1.0 - t, 2.0))
            let control2x = controlPoint2.x * CGFloat(3.0 * (1.0 - t) * powf(t, 2.0))
            let endx = endPoint.x * CGFloat(powf(t, 3))
            
            let movey = movePoint.y * CGFloat(powf(1.0 - t, 3.0))
            let control1y = controlPoint1.y * CGFloat(3.0 * t * powf(1.0 - t, 2.0))
            let control2y = controlPoint2.y * CGFloat(3.0 * (1.0 - t) * powf(t, 2.0))
            let endy = endPoint.y * CGFloat(powf(t, 3.0))
            
            result.append(CGPoint(x: movex + control1x + control2x + endx,
                                  y: movey + control1y + control2y + endy))
            
            t += step
        }
        if addLastPoint {
            result.append(endPoint)
        }
        
        return result
    }
    
    static func linear(begin: CGFloat, change: CGFloat, duration: Int, addLastPoint: Bool = false) -> [CGFloat] {
        
        var result: [CGFloat] = []
        
        for t in 0 ..< duration {
            
            let difference = (change - begin)
            let normalizedValue = CGFloat(Float(t) / Float(duration))
            
            result.append(difference * normalizedValue + begin)
        }
        if addLastPoint {
            result.append(change)
        }
        
        return result
    }
}

private extension CGVector {
    init(lhs: CGPoint, rhs: CGPoint) {
        self.init(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}
