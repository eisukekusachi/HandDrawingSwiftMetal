//
//  MTLTextureCoordinates.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/11/23.
//

import Foundation

struct MTLTextureCoordinates {
    let LT: CGPoint
    let RT: CGPoint
    let RB: CGPoint
    let LB: CGPoint

    func getValues() -> [Float] {
        [
            Float(LB.x), Float(LB.y),
            Float(RB.x), Float(RB.y),
            Float(RT.x), Float(RT.y),
            Float(LT.x), Float(LT.y)
        ]
    }

    /// UV coordinates for a screen coordinate system with the origin at the top-left corner.
    /// This is typical in `UIKit`, where (0,0) represents the top-left of the screen.
    static let screenTextureCoordinates: Self = .init(
        LT: .init(x: 0.0, y: 0.0),
        RT: .init(x: 1.0, y: 0.0),
        RB: .init(x: 1.0, y: 1.0),
        LB: .init(x: 0.0, y: 1.0)
    )

    /// UV coordinates for a Cartesian coordinate system with the origin at the bottom-left corner
    /// Commonly used in `Metal` rendering, where the bottom-left is (0,0).
    static let cartesianTextureCoordinates: Self = .init(
        LT: .init(x: 0.0, y: 1.0),
        RT: .init(x: 1.0, y: 1.0),
        RB: .init(x: 1.0, y: 0.0),
        LB: .init(x: 0.0, y: 0.0)
    )

}
