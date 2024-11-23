//
//  MTLTextureIndices.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/11/23.
//

import Foundation

struct MTLTextureIndices {
    var LB: UInt16 = 0
    var RB: UInt16 = 1
    var RT: UInt16 = 2
    var LT: UInt16 = 3

    static func getOffset(nodeCount: Int) -> UInt16 {
        UInt16(nodeCount * 4)
    }

    func getValues() -> [UInt16] {
        [
            LB, RB, RT,
            LB, RT, LT
        ]
    }
}

extension MTLTextureIndices {

    init(offset: UInt16 = 0) {
        LB = 0 + offset
        RB = 1 + offset
        RT = 2 + offset
        LT = 3 + offset
    }

}
