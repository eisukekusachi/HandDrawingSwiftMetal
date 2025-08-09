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
    static let activatingDrawingDuration: TimeInterval = 0.1
    static let activatingTransformingDuration: TimeInterval = 0.05

    static func isDrawingGesture(_ touchHistories: TouchHistoriesOnScreen) -> Self? {
        guard touchHistories.count == 1,
              let history = touchHistories.first?.value,
              let first = history.first,
              let last = history.last else { return nil }

        let duration = last.timestamp - first.timestamp
        if duration > activatingDrawingDuration {
            return .drawing
        }
        return nil
    }

    static func isTransformingGesture(_ touchHistories: TouchHistoriesOnScreen) -> Self? {
        guard touchHistories.count == 2 else { return nil }
        guard let firstHistory = touchHistories.first,
              let lastHistory = touchHistories.last,
              let firstA = firstHistory.first,
              let lastA = firstHistory.last,
              let firstB = lastHistory.first,
              let lastB = lastHistory.last else { return nil }

        let durationA = lastA.timestamp - firstA.timestamp
        let durationB = lastB.timestamp - firstB.timestamp

        if durationA > activatingTransformingDuration && durationB > activatingTransformingDuration {
            return .transforming
        }
        return nil
    }
}
