//
//  PencilStroke.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

/// Manages the pen position information sent from the Apple Pencil.
final class PencilStroke {

    /// An array that stores real values.
    /// https://developer.apple.com/documentation/uikit/apple_pencil_interactions/handling_input_from_apple_pencil/
    /// The Apple Pencil provides both estimated and actual values, but drawing is primarily based on the actual values.
    private(set) var actualTouchPointArray: [TouchPoint] = []

    /// The last touch point that was drawn.
    private(set) var lastDrawnTouchPoint: TouchPoint?

    /// A variable that stores the latest estimated value, used for determining touch end
    private(set) var latestEstimatedTouchPoint: TouchPoint?

    /// A variable that stores the latest estimationUpdateIndex, used for determining touch end
    private(set) var latestEstimationUpdateIndex: NSNumber?

    init(
        actualTouchPointArray: [TouchPoint] = [],
        latestEstimatedTouchPoint: TouchPoint? = nil,
        lastDrawnTouchPoint: TouchPoint? = nil
    ) {
        self.actualTouchPointArray = actualTouchPointArray.sorted { $0.timestamp < $1.timestamp }
        self.latestEstimatedTouchPoint = latestEstimatedTouchPoint
        self.latestEstimationUpdateIndex = latestEstimatedTouchPoint?.estimationUpdateIndex
        self.lastDrawnTouchPoint = lastDrawnTouchPoint
    }
}

extension PencilStroke {
    /// Gets points from the specified start element to the end
    func drawingPoints(after touchPoint: TouchPoint?) -> [TouchPoint] {
        actualTouchPointArray.elements(after: touchPoint) ?? actualTouchPointArray
    }

    /// Sets the latest estimated value
    func setLatestEstimatedTouchPoint(_ estimatedTouchPoint: TouchPoint?) {
        guard let estimatedTouchPoint else { return }

        latestEstimatedTouchPoint = estimatedTouchPoint

        guard let estimationUpdateIndex = estimatedTouchPoint.estimationUpdateIndex else { return }

        // During the `.moved` phase, estimationUpdateIndex is continuously updated.
        // When the touchPhase changes to `.ended`, it becomes nil,
        // so the most recent value is retained in latestEstimationUpdateIndex.
        latestEstimationUpdateIndex = estimationUpdateIndex
    }

    /// Sets `lastDrawnTouchPoint` to the last touch point in the drawing history.
    func setLastDrawnTouchPoint() {
        guard let touchPoint = actualTouchPointArray.last else { return }
        lastDrawnTouchPoint = touchPoint
    }

    func shouldFinalizeDrawing(from pointArray: [TouchPoint]) -> Bool {
        StrokePointState(points: pointArray).shouldFinalizeDrawing
    }

    /// Appends  the actual values to the array
    func appendActualTouches(actualTouches: [TouchPoint]) {
        actualTouchPointArray.append(contentsOf: actualTouches)

        guard
            !actualTouches.contains(where: { $0.phase == .ended || $0.phase == .cancelled }),
            isPenOffScreen(actualTouches: actualTouches),
            let latestEstimatedTouchPoint
        else { return }

        actualTouchPointArray.append(latestEstimatedTouchPoint)
    }

    func reset() {
        actualTouchPointArray = []
        latestEstimatedTouchPoint = nil
        latestEstimationUpdateIndex = nil
        lastDrawnTouchPoint = nil
    }
}

extension PencilStroke {
    private func isPenOffScreen(actualTouches: [TouchPoint]) -> Bool {
        // Apple Pencil sends estimated values and actual values to the device.
        // In practice, the actual values do not include touchPhase.ended, so estimated values are used instead.
        // According to the Apple Pencil specification, estimated values are sent first, followed by actual values.
        // Therefore, when the index of the latest estimated value matches the index of the latest actual value,
        // Since there are no more actual values to be sent, it is determined that the pen has been lifted from the screen.
        // In practice, the estimated values include touchPhase.ended, so this should be checked as well.
        actualTouches.contains(where: { $0.estimationUpdateIndex == latestEstimationUpdateIndex }) &&
        latestEstimatedTouchPoint?.phase == .ended
    }
}
