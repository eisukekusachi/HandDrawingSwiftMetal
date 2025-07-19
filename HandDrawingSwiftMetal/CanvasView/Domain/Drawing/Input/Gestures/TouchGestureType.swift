//
//  TouchGestureType.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

enum TouchGestureType: Int {
    /// The status is still undetermined
    case undetermined

    case drawing

    case transforming

    init(from touchPointsDictionary: [TouchHashValue: [TouchPoint]]) {
        var result: TouchGestureType = .undetermined

        if let actionState = TouchGestureType.isDrawingGesture(touchPointsDictionary) {
            result = actionState

        } else if let actionState = TouchGestureType.isTransformingGesture(touchPointsDictionary) {
            result = actionState
        }

        self = result
    }
}

extension TouchGestureType {

    static let activatingDrawingCount: Int = 6
    static let activatingTransformingCount: Int = 2

    static func isDrawingGesture(_ touchPointsDictionary: [TouchHashValue: [TouchPoint]]) -> Self? {
        if touchPointsDictionary.count != 1 { return nil }

        if let count = touchPointsDictionary.first?.count, count > activatingDrawingCount {
            return .drawing
        }
        return nil
    }
    static func isTransformingGesture(_ touchPointsDictionary: [TouchHashValue: [TouchPoint]]) -> Self? {
        if touchPointsDictionary.count != 2 { return nil }

        if let countA = touchPointsDictionary.first?.count, countA > activatingTransformingCount,
           let countB = touchPointsDictionary.last?.count, countB > activatingTransformingCount {
            return .transforming
        }
        return nil
    }
}
