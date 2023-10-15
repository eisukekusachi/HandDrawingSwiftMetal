//
//  DefaultPointToCurveConverter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation

class DefaultPointStorage: TouchPointStorageProtocol {
    var storedPoints: [TouchPoint] = []
    var iterator = Iterator<TouchPoint>()

    func appendPoints(_ touchPoints: [TouchPoint]) {
        storedPoints.append(contentsOf: touchPoints)
        iterator.update(elems: storedPoints)
    }
    func getIterator(endProcessing: Bool = false) -> Iterator<TouchPoint> {
        return iterator
    }
    
    func reset() {
        storedPoints = []
        iterator.reset()
    }
}
