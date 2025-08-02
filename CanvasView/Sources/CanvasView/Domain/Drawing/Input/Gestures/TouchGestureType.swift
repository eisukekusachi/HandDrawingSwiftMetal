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

    init(from touchHistories: TouchHistoriesOnScreen) {
        var result: TouchGestureType = .undetermined

        if let actionState = TouchGestureType.isDrawingGesture(touchHistories) {
            result = actionState

        } else if let actionState = TouchGestureType.isTransformingGesture(touchHistories) {
            result = actionState
        }

        self = result
    }
}

extension TouchGestureType {

    static let activatingDrawingCount: Int = 6
    static let activatingTransformingCount: Int = 2

    static func isDrawingGesture(_ touchHistories: TouchHistoriesOnScreen) -> Self? {
        if touchHistories.count != 1 { return nil }

        if let count = touchHistories.first?.count, count > activatingDrawingCount {
            return .drawing
        }
        return nil
    }
    static func isTransformingGesture(_ touchHistories: TouchHistoriesOnScreen) -> Self? {
        if touchHistories.count != 2 { return nil }

        if let countA = touchHistories.first?.count, countA > activatingTransformingCount,
           let countB = touchHistories.last?.count, countB > activatingTransformingCount {
            return .transforming
        }
        return nil
    }
}
