//
//  DefaultPointToCurveConverter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation

class DefaultPointStorage: PointStorage {
    
    typealias Input = [TouchPoint]
    typealias StoredPoints = [TouchPoint]
    typealias Output = TouchPoint
    
    var storedPoints: StoredPoints = []
    var iterator = Iterator<Output>()
    
    func appendPoints(_ input: Input) {
        storedPoints.append(contentsOf: input)
        iterator.update(elems: storedPoints)
    }
    func getIterator(endProcessing: Bool = false) -> Iterator<Output> {
        return iterator
    }
    
    func reset() {
        storedPoints = []
        iterator.reset()
    }
}
