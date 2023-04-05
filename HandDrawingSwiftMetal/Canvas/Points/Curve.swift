//
//  Curve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/31.
//

import Foundation

enum Curve {
    
    static func makePoints(iterator: Iterator<Point>,
                           matrix: CGAffineTransform? = nil,
                           srcSize: CGSize,
                           dstSize: CGSize,
                           endProcessing: Bool = false) -> [Point] {
        var curve: [Point] = []
        
        while let subsequece = iterator.next(range: 4) {
            
            if iterator.isFirstProcessing {
                let points = makeFirstPoints(iterator: iterator,
                                             matrix: matrix,
                                             srcSize: srcSize,
                                             dstSize: dstSize)
                curve.append(contentsOf: points)
            }
            
            var previous = subsequece[0].scale(srcSize: srcSize, dstSize: dstSize)
            var start = subsequece[1].scale(srcSize: srcSize, dstSize: dstSize)
            var end = subsequece[2].scale(srcSize: srcSize, dstSize: dstSize)
            var next = subsequece[3].scale(srcSize: srcSize, dstSize: dstSize)
            
            previous = previous.center(srcSize: srcSize, dstSize: dstSize)
            start = start.center(srcSize: srcSize, dstSize: dstSize)
            end = end.center(srcSize: srcSize, dstSize: dstSize)
            next = next.center(srcSize: srcSize, dstSize: dstSize)
            
            if let matrix = matrix {
                previous = previous.apply(matrix: matrix, textureSize: dstSize)
                start = start.apply(matrix: matrix, textureSize: dstSize)
                end = end.apply(matrix: matrix, textureSize: dstSize)
                next = next.apply(matrix: matrix, textureSize: dstSize)
            }
            curve.append(contentsOf: Interpolator.curve(previousPoint: previous,
                                                        startPoint: start,
                                                        endPoint: end,
                                                        nextPoint: next))
        }
        
        if endProcessing {
            if iterator.index == 0 {
                let points = makeFirstPoints(iterator: iterator,
                                             matrix: matrix,
                                             srcSize: srcSize,
                                             dstSize: dstSize)
                curve.append(contentsOf: points)
            }
            
            let points = makeLastPoints(iterator: iterator,
                                        matrix: matrix,
                                        srcSize: srcSize,
                                        dstSize: dstSize)
            curve.append(contentsOf: points)
        }
        
        return curve
    }
    
    static func makeFirstPoints(iterator: Iterator<Point>,
                                matrix: CGAffineTransform? = nil,
                                srcSize: CGSize,
                                dstSize: CGSize) -> [Point] {
        if iterator.array.count < 3 { return [] }
        
        let index0 = 0
        let index1 = 1
        let index2 = 2
        
        var previous = iterator.array[index0].scale(srcSize: srcSize, dstSize: dstSize)
        var start = iterator.array[index1].scale(srcSize: srcSize, dstSize: dstSize)
        var end = iterator.array[index2].scale(srcSize: srcSize, dstSize: dstSize)
        
        previous = previous.center(srcSize: srcSize, dstSize: dstSize)
        start = start.center(srcSize: srcSize, dstSize: dstSize)
        end = end.center(srcSize: srcSize, dstSize: dstSize)
        
        if let matrix = matrix {
            previous = previous.apply(matrix: matrix, textureSize: dstSize)
            start = start.apply(matrix: matrix, textureSize: dstSize)
            end = end.apply(matrix: matrix, textureSize: dstSize)
        }
        
        return Interpolator.firstCurve(previousPoint: previous,
                                       startPoint: start,
                                       endPoint: end,
                                       addLastPoint: false)
    }
    static func makeLastPoints(iterator: Iterator<Point>,
                               matrix: CGAffineTransform? = nil,
                               srcSize: CGSize,
                               dstSize: CGSize) -> [Point] {
        if iterator.array.count < 3 { return [] }
        
        let index0 = iterator.array.count - 3
        let index1 = iterator.array.count - 2
        let index2 = iterator.array.count - 1
        
        var start = iterator.array[index0].scale(srcSize: srcSize, dstSize: dstSize)
        var end = iterator.array[index1].scale(srcSize: srcSize, dstSize: dstSize)
        var next = iterator.array[index2].scale(srcSize: srcSize, dstSize: dstSize)
        
        start = start.center(srcSize: srcSize, dstSize: dstSize)
        end = end.center(srcSize: srcSize, dstSize: dstSize)
        next = next.center(srcSize: srcSize, dstSize: dstSize)
        
        if let matrix = matrix {
            start = start.apply(matrix: matrix, textureSize: dstSize)
            end = end.apply(matrix: matrix, textureSize: dstSize)
            next = next.apply(matrix: matrix, textureSize: dstSize)
        }
        
        return Interpolator.lastCurve(startPoint: start,
                                      endPoint: end,
                                      nextPoint: next,
                                      addLastPoint: true)
    }
}
