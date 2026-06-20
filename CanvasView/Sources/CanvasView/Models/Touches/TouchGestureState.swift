//
//  TouchGestureState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class TouchGestureState {

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

extension TouchGestureState {

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

private extension TouchGestureState {

    func isDrawingGesture(_ touchHistories: TouchHistoriesOnScreen) -> TouchGestureType? {
        guard
            touchHistories.count == 1,
            let history = touchHistories.first?.value,
            let first = history.first,
            let last = history.last
        else { return nil }

        // If the touch has already ended, treat it as a drawing gesture even if it was very short.
        // This prevents short strokes (e.g. after large zoom) from being ignored, while still
        // avoiding accidental marks when the user is about to start a two-finger pinch.
        if last.phase == .ended || last.phase == .cancelled {
            return .drawing
        }

        // Otherwise, wait a short grace period to distinguish drawing from two-finger transforming.
        if (last.timestamp - first.timestamp) >= drawingGestureRecognitionSecond {
            return .drawing
        }
        return nil
    }

    func isTransformingGesture(_ touchHistories: TouchHistoriesOnScreen) -> TouchGestureType? {
        guard touchHistories.count == 2 else { return nil }

        let keys = Array(touchHistories.keys)
        let keyFirst = keys[0]
        let keySecond = keys[1]

        guard
            let firstHistory = touchHistories[keyFirst],
            let secondHistory = touchHistories[keySecond],
            let firstFirstA = firstHistory.first,
            let firstLastA = firstHistory.last,
            let secondFirstB = secondHistory.first,
            let secondLastB = secondHistory.last
        else { return nil }

        if  (firstLastA.timestamp - firstFirstA.timestamp) >= transformingGestureRecognitionSecond &&
            (secondLastB.timestamp - secondFirstB.timestamp) >= transformingGestureRecognitionSecond {
            return .transforming
        }
        return nil
    }
}
