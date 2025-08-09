//
//  TouchGestureState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

public final class TouchGestureState {

    private(set) var status: TouchGestureType

    private var drawingGestureRecognitionSecond: TimeInterval
    private var transformingGestureRecognitionSecond: TimeInterval

    init(
        _ status: TouchGestureType = .undetermined,
        drawingGestureRecognitionSecond: TimeInterval = 0.1,
        transformingGestureRecognitionSecond: TimeInterval = 0.05
    ) {
        self.status = status
        self.drawingGestureRecognitionSecond = drawingGestureRecognitionSecond
        self.transformingGestureRecognitionSecond = transformingGestureRecognitionSecond
    }
}

public extension TouchGestureState {

    func setDrawingGestureRecognitionSecond(_ second: TimeInterval) {
        drawingGestureRecognitionSecond = second
    }

    func setTransformingGestureRecognitionSecond(_ second: TimeInterval) {
        transformingGestureRecognitionSecond = second
    }

    func touchGestureType(from touchHistories: TouchHistoriesOnScreen) -> TouchGestureType {
        isDrawingGesture(touchHistories) ??
        isTransformingGesture(touchHistories) ??
        .undetermined
    }

    /// Update the status if the status is not yet determined
    func update(
        _ touchHistories: TouchHistoriesOnScreen
    ) -> TouchGestureType {
        if status == .undetermined {
            status = touchGestureType(from: touchHistories)
        }
        return status
    }

    func reset() {
        status = .undetermined
    }
}

public extension TouchGestureState {

    private func isDrawingGesture(_ touchHistories: TouchHistoriesOnScreen) -> TouchGestureType? {
        guard
            touchHistories.count == 1,
            let history = touchHistories.first?.value,
            let first = history.first,
            let last = history.last
        else { return nil }

        let duration = last.timestamp - first.timestamp
        if duration > drawingGestureRecognitionSecond {
            return .drawing
        }
        return nil
    }

    private func isTransformingGesture(_ touchHistories: TouchHistoriesOnScreen) -> TouchGestureType? {
        guard
            touchHistories.count == 2,
            let firstHistory = touchHistories.first,
            let lastHistory = touchHistories.last,
            let firstA = firstHistory.first,
            let lastA = firstHistory.last,
            let firstB = lastHistory.first,
            let lastB = lastHistory.last
        else { return nil }

        let secondA = lastA.timestamp - firstA.timestamp
        let secondB = lastB.timestamp - firstB.timestamp

        if  secondA > transformingGestureRecognitionSecond &&
            secondB > transformingGestureRecognitionSecond {
            return .transforming
        }
        return nil
    }
}
