//
//  Curve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/31.
//

import Foundation

enum Curve {
    static func makePoints(iterator: Iterator<TouchPoint>,
                           matrix: CGAffineTransform? = nil,
                           srcSize: CGSize,
                           dstSize: CGSize,
                           endProcessing: Bool = false) -> [TouchPoint] {
        return []
    }
    
    static func makeFirstPoints(iterator: Iterator<TouchPoint>,
                                matrix: CGAffineTransform? = nil,
                                srcSize: CGSize,
                                dstSize: CGSize) -> [TouchPoint] {
        return []
    }
    static func makeLastPoints(iterator: Iterator<TouchPoint>,
                               matrix: CGAffineTransform? = nil,
                               srcSize: CGSize,
                               dstSize: CGSize) -> [TouchPoint] {
        return []
    }
}
