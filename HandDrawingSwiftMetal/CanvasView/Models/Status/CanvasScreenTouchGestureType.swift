//
//  CanvasScreenTouchGestureType.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

enum CanvasScreenTouchGestureType: Int {
    /// The status is still undetermined
    case undetermined

    case drawing

    case transforming

    init(from touchPointsDictionary: [TouchHashValue: [TouchPoint]]) {
        var result: CanvasScreenTouchGestureType = .undetermined

        if let actionState = CanvasScreenTouchGestureType.isDrawingGesture(touchPointsDictionary) {
            result = actionState

        } else if let actionState = CanvasScreenTouchGestureType.isTransformingGesture(touchPointsDictionary) {
            result = actionState
        }

        self = result
    }

}

extension CanvasScreenTouchGestureType {

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
