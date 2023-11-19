//
//  DefaultTouchPointStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation

class DefaultTouchPointStorage: TouchPointStorageProtocol {
    var touchPointArray: [TouchPoint] = []
    var iterator = Iterator<TouchPoint>()

    func appendPoints(_ touchPoints: [TouchPoint]) {
        touchPointArray.append(contentsOf: touchPoints)
        iterator.update(elems: touchPointArray)
    }
    func getIterator(endProcessing: Bool = false) -> Iterator<TouchPoint> {
        return iterator
    }
    
    func clear() {
        touchPointArray = []
        iterator.clear()
    }
}
