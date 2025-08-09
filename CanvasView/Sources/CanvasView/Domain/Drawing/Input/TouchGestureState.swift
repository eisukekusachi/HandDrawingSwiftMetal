//
//  TouchGestureState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

public final class TouchGestureState {

    private(set) var status: TouchGestureType

    let activatingDrawingDuration: TimeInterval
    let activatingTransformingDuration: TimeInterval

    init(
        _ status: TouchGestureType = .undetermined,
        activatingDrawingDuration: TimeInterval = 0.1,
        activatingTransformingDuration: TimeInterval = 0.05
    ) {
        self.status = status
        self.activatingDrawingDuration = activatingDrawingDuration
        self.activatingTransformingDuration = activatingTransformingDuration
    }
}

public extension TouchGestureState {

    func update(
        _ touchHistories: TouchHistoriesOnScreen
    ) -> TouchGestureType {
        update(
            touchGestureType(from: touchHistories)
        )
    }

    /// Update the status if the status is not yet determined.
    func update(
        _ type: TouchGestureType
    ) -> TouchGestureType {
        if status == .undetermined {
            status = type
        }
        return status
    }

    func reset() {
        status = .undetermined
    }
}

public extension TouchGestureState {

    func touchGestureType(from touchHistories: TouchHistoriesOnScreen) -> TouchGestureType {
        isDrawingGesture(touchHistories) ??
        isTransformingGesture(touchHistories) ??
        .undetermined
    }

    func isDrawingGesture(_ touchHistories: TouchHistoriesOnScreen) -> TouchGestureType? {
        guard
            touchHistories.count == 1,
            let history = touchHistories.first?.value,
            let first = history.first,
            let last = history.last
        else { return nil }

        let duration = last.timestamp - first.timestamp
        if duration > activatingDrawingDuration {
            return .drawing
        }
        return nil
    }

    func isTransformingGesture(_ touchHistories: TouchHistoriesOnScreen) -> TouchGestureType? {
        guard
            touchHistories.count == 2,
            let firstHistory = touchHistories.first,
            let lastHistory = touchHistories.last,
            let firstA = firstHistory.first,
            let lastA = firstHistory.last,
            let firstB = lastHistory.first,
            let lastB = lastHistory.last
        else { return nil }

        let durationA = lastA.timestamp - firstA.timestamp
        let durationB = lastB.timestamp - firstB.timestamp

        if  durationA > activatingTransformingDuration &&
            durationB > activatingTransformingDuration {
            return .transforming
        }
        return nil
    }
}
