//
//  ArrayExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
extension Array where Element == CGPoint {
    func splite(ratio: [CGFloat]) -> [CGPoint] {
        var result: [CGPoint] = []
        if self.count < 1 || ratio.count == 0 { return result }
        for i in 0 ..< self.count - 1 {
            let pt0 = self[i]
            let pt1 = self[i + 1]
            let vector = CGVector(pt0, to: pt1)
            for value in ratio {
                let newVector = vector.resizeTo(length: vector.length() * value)
                result.append(pt0.add(vector: newVector))
            }
        }
        return result
    }
    func vertexCoordinate(_ size: CGSize) -> [CGPoint] {
        return self.map { $0.divide(size).multiBy2Sub1() }
    }
    func multiply(_ value: CGFloat) -> [CGPoint] {
        return self.map { $0.multiply(value) }
    }
}
extension Array where Element == CGFloat {
    func splite(ratio: [CGFloat]) -> [CGFloat] {
        var result: [CGFloat] = []
        if self.count < 1 || ratio.count == 0 { return result }
        for i in 0 ..< self.count - 1 {
            let val0 = self[i]
            let val1 = self[i + 1]
            let diff = val1 - val0
            for value in ratio {
                result.append(diff * value + val0)
            }
        }
        return result
    }
}
