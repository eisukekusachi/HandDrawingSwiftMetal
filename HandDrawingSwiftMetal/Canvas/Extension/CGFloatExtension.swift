//
//  CGFloatExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/01/22.
//

import UIKit
extension CGFloat {
    func toSize() -> CGSize {
        return CGSize(width: self, height: self)
    }
    func toRadian() -> CGFloat {
        return self * (3.14 / 180.0)
    }
    func toDegree() -> CGFloat {
        return self * (180.0 / 3.14)
    }
    func difference(_ value: CGFloat) -> CGFloat {
        var smallerNumber: CGFloat = self
        var largerNumber: CGFloat = value
        if smallerNumber > largerNumber {
            let tmpNumber = largerNumber
            largerNumber = smallerNumber
            smallerNumber = tmpNumber
        }
        return largerNumber - smallerNumber
    }
    func smallestAngluarDifference(_ angle: CGFloat) -> Int {
        var smallerNumber: Int = Int(self) % 360
        var largerNumber: Int = Int(angle) % 360
        if smallerNumber > largerNumber {
            let tmpNumber = largerNumber
            largerNumber = smallerNumber
            smallerNumber = tmpNumber
        }
        let reuslt0: Int = largerNumber - smallerNumber
        let reuslt1: Int = (180 - abs(Int(self))) + (180 - abs(Int(angle)))
        if reuslt0 < reuslt1 {
            return reuslt0
        } else {
            return reuslt1
        }
    }
    func angularDifference(from: CGFloat) -> CGFloat {
        var src = from
        var dst = self
        while src < -180 { src = src + 360 }
        while src >= 180 { src = src - 360 }
        while dst < -180 { dst = dst + 360 }
        while dst >= 180 { dst = dst - 360 }
        var angle = dst - src
        while angle < -180 { angle = angle + 360 }
        while angle >= 180 { angle = angle - 360 }
        return angle
    }
    func angularDifference(to: CGFloat) -> CGFloat {
        var src = self
        var dst = to
        while src < -180 { src = src + 360 }
        while src >= 180 { src = src - 360 }
        while dst < -180 { dst = dst + 360 }
        while dst >= 180 { dst = dst - 360 }
        var angle = dst - src
        while angle < -180 { angle = angle + 360 }
        while angle >= 180 { angle = angle - 360 }
        return angle
    }
}
