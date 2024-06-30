//
//  CGPointExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/02.
//

import UIKit

extension CGPoint {

    func apply(matrix: CGAffineTransform, textureSize: CGSize) -> Self {
        var location = self

        location = CGPoint(x: location.x - textureSize.width * 0.5,
                           y: location.y - textureSize.height * 0.5)

        location = CGPoint(x: (location.x * matrix.a + location.y * matrix.c + matrix.tx),
                           y: (location.x * matrix.b + location.y * matrix.d + matrix.ty))

        location = CGPoint(x: location.x + textureSize.width * 0.5,
                           y: location.y + textureSize.height * 0.5)

        return location
    }

    func center(srcSize: CGSize, dstSize: CGSize) -> Self {
        var location = self

        let scaleFrameToTexture = Aspect.getScaleToFit(srcSize, to: dstSize)

        let srcSize = CGSize(width: (srcSize.width * scaleFrameToTexture),
                             height: (srcSize.height * scaleFrameToTexture))

        let offsetForCentering = Calc.getOffsetForCentering(src: srcSize, dst: dstSize)

        location = CGPoint(x: location.x + offsetForCentering.x,
                           y: location.y + offsetForCentering.y)

        return location
    }

    func offset(_ offset: Self) -> Self {
        return CGPoint(x: self.x + offset.x,
                       y: self.y + offset.y)
    }

    func scale(_ sourceSize: CGSize, to destinationSize: CGSize) -> Self {
        let scaleFrameToTexture = ViewSize.getScaleToFit(sourceSize, to: destinationSize)

        return .init(
            x: self.x * scaleFrameToTexture,
            y: self.y * scaleFrameToTexture
        )
    }

}
