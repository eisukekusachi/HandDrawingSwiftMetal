//
//  TouchGestureState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

public final class TouchGestureState {

    private(set) var state: TouchGestureType

    private var drawingGestureRecognitionSecond: TimeInterval
    private var transformingGestureRecognitionSecond: TimeInterval

    init(
        _ state: TouchGestureType = .undetermined,
        drawingGestureRecognitionSecond: TimeInterval = 0.1,
        transformingGestureRecognitionSecond: TimeInterval = 0.05
    ) {
        self.state = state
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

    /// Update the state if the state is not yet determined
    @discardableResult
    func update(
        _ touchHistories: TouchHistoriesOnScreen
    ) -> TouchGestureType {
        if state == .undetermined {
            state = touchGestureType(from: touchHistories)
        }
        return state
    }

    func reset() {
        state = .undetermined
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

        if (last.timestamp - first.timestamp) >= drawingGestureRecognitionSecond {
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

        if  (lastA.timestamp - firstA.timestamp) >= transformingGestureRecognitionSecond &&
            (lastB.timestamp - firstB.timestamp) >= transformingGestureRecognitionSecond {
            return .transforming
        }
        return nil
    }
}
