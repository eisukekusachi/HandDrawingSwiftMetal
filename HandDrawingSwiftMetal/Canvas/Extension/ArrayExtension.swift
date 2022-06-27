//
//  ArrayExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
extension Array where Element == CGPoint {
    func vertexCoordinate(_ size: CGSize) -> [CGPoint] {
        return self.map { $0.divided(size).multiBy2Sub1() }
    }
    func multiplied(_ value: CGFloat) -> [CGPoint] {
        return self.map { $0.multiplied(value) }
    }
}
