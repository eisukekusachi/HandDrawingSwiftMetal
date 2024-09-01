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

}
