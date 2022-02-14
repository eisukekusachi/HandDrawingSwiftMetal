//
//  ArrayExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
extension Array where Element == CGPoint {
    func splitted(ratioArray: [CGFloat]) -> [CGPoint] {
        var result: [CGPoint] = []
        if self.count < 1 || ratioArray.count == 0 { return result }
        for i in 0 ..< self.count - 1 {
            let pt0 = self[i]
            let pt1 = self[i + 1]
            let vector = CGVector(pt0, to: pt1)
            for ratio in ratioArray {
                let newVector = vector.resizeTo(length: vector.length() * ratio)
                result.append(pt0.add(vector: newVector))
            }
        }
        return result
    }
    func vertexCoordinate(_ size: CGSize) -> [CGPoint] {
        return self.map { $0.divided(size).multiBy2Sub1() }
    }
    func multiplied(_ value: CGFloat) -> [CGPoint] {
        return self.map { $0.multiplied(value) }
    }
}
extension Array where Element == CGFloat {
    func splitted(ratioArray: [CGFloat]) -> [CGFloat] {
        var result: [CGFloat] = []
        if self.count < 1 || ratioArray.count == 0 { return result }
        for i in 0 ..< self.count - 1 {
            let val0 = self[i]
            let val1 = self[i + 1]
            let diff = val1 - val0
            for ratio in ratioArray {
                result.append(diff * ratio + val0)
            }
        }
        return result
    }
}
