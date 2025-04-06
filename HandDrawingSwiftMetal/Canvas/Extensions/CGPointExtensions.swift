//
//  CGPointExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/02.
//

import UIKit

extension CGPoint {

    func apply(
        with matrix: CGAffineTransform,
        textureSize: CGSize
    ) -> Self {

        var point = self

        point = .init(
            x: point.x - textureSize.width * 0.5,
            y: point.y - textureSize.height * 0.5
        )
        point = .init(
            x: (point.x * matrix.a + point.y * matrix.c + matrix.tx),
            y: (point.x * matrix.b + point.y * matrix.d + matrix.ty)
        )
        point = .init(
            x: point.x + textureSize.width * 0.5,
            y: point.y + textureSize.height * 0.5
        )

        return point
    }

    func scale(_ sourceSize: CGSize, to destinationSize: CGSize) -> Self {
        let scaleFrameToTexture = ViewSize.getScaleToFit(sourceSize, to: destinationSize)

        return .init(
            x: self.x * scaleFrameToTexture,
            y: self.y * scaleFrameToTexture
        )
    }

    func distance(_ to: CGPoint?) -> CGFloat {
        guard let value = to else { return 0.0 }
        return sqrt(pow(value.x - x, 2) + pow(value.y - y, 2))
    }

}
