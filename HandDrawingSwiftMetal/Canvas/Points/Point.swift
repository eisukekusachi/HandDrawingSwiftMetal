//
//  PointAndValue.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

protocol Point {
    
    var location: CGPoint { get set }
    var alpha: CGFloat { get set } // alpha must be a floating point number in the range 0.0 ~ 1.0.
}

extension Point {
    
    func apply(matrix: CGAffineTransform, textureSize: CGSize) -> Self {
        var point = self
        
        var location = self.location
        
        location = CGPoint(x: location.x - textureSize.width * 0.5,
                           y: location.y - textureSize.height * 0.5)
        
        location = CGPoint(x: (location.x * matrix.a + location.y * matrix.c + matrix.tx),
                           y: (location.x * matrix.b + location.y * matrix.d + matrix.ty))
        
        location = CGPoint(x: location.x + textureSize.width * 0.5,
                           y: location.y + textureSize.height * 0.5)
        
        point.location = location
        
        return point
    }
    
    func center(srcSize: CGSize, dstSize: CGSize) -> Self {
        var point = self
        
        let scaleFrameToTexture = Aspect.getScaleToFit(srcSize, to: dstSize)
        
        let srcSize = CGSize(width: (srcSize.width * scaleFrameToTexture),
                             height: (srcSize.height * scaleFrameToTexture))
        
        let offsetForCentering = Calc.getOffsetForCentering(src: srcSize, dst: dstSize)
        
        point.location = CGPoint(x: self.location.x + offsetForCentering.x,
                                 y: self.location.y + offsetForCentering.y)
        
        return point
    }
    
    func offset(_ offset: CGPoint) -> Self {
        var point = self
        
        point.location = CGPoint(x: self.location.x + offset.x, y: self.location.y + offset.y)
        
        return point
    }
    
    func scale(srcSize: CGSize, dstSize: CGSize) -> Self {
        var point = self
        
        let scaleFrameToTexture = Aspect.getScaleToFit(srcSize, to: dstSize)
        
        point.location = CGPoint(x: (self.location.x * scaleFrameToTexture),
                                 y: (self.location.y * scaleFrameToTexture))
        
        return point
    }
}

struct PointImpl: Point, Equatable {
    
    var location: CGPoint
    var alpha: CGFloat {
        didSet {
            alpha = max(0.0, min(alpha, 1.0))
        }
    }
    
    init(touch: UITouch, view: UIView, alpha: CGFloat? = nil) {
        self.location = touch.preciseLocation(in: view)
        self.alpha = alpha ?? max(0.0, min(touch.force, 1.0))
    }
    
    init(location: CGPoint, alpha: CGFloat) {
        self.location = location
        self.alpha = max(0.0, min(alpha, 1.0))
    }
}
