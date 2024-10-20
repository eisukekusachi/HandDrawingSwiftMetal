//
//  CanvasPencilScreenTouchPoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit
/// https://developer.apple.com/documentation/uikit/apple_pencil_interactions/handling_input_from_apple_pencil/
/// Since an Apple Pencil is a separate device from an iPad,
/// `UIGestureRecognizer` initially sends estimated values and then sends the actual values shortly after.
///  This class is a model that combines estimated and actual values to create an array of `CanvasTouchPoint`.
///  It stores the estimated values in `estimatedTouchPointArray` and then combines them with the actual values received later
///  to create the values for `actualTouchPointArray`.
final class CanvasPencilScreenTouchPoints {

    /// An array that holds elements combining actualTouches, where the force values are accurate, and estimatedTouchPointArray.
    private (set) var actualTouchPointArray: [CanvasTouchPoint] = []

    /// An array that holds estimated values where the TouchPhase values are accurate.
    private (set) var estimatedTouchPointArray: [CanvasTouchPoint] = []

    /// An index of the processed elements in `estimatedTouchPointArray`
    private (set) var latestEstimatedTouchArrayIndex = 0

    /// An element processed in `actualTouchPointArray`
    private (set) var latestActualTouchPoint: CanvasTouchPoint? = nil

    private (set) var lastEstimationUpdateIndexAtCompletion: NSNumber? = nil

    /// A variable used to get elements from the array starting from the next element after this point
    var latestCanvasTouchPoint: CanvasTouchPoint?

    init(
        actualTouchPointArray: [CanvasTouchPoint] = [],
        estimatedTouchPointArray: [CanvasTouchPoint] = [],
        latestEstimatedTouchArrayIndex: Int = 0,
        latestActualTouchPoint: CanvasTouchPoint? = nil
    ) {
        self.actualTouchPointArray = actualTouchPointArray
        self.estimatedTouchPointArray = estimatedTouchPointArray
        self.latestEstimatedTouchArrayIndex = latestEstimatedTouchArrayIndex
        self.latestActualTouchPoint = latestActualTouchPoint
    }

}

extension CanvasPencilScreenTouchPoints {

    /// Use the elements of `actualTouchPointArray` after `latestActualTouchPoint` for line drawing
    func getLatestTouchPoints() -> [CanvasTouchPoint] {
        let touchPoints = actualTouchPointArray.elements(after: latestActualTouchPoint) ?? actualTouchPointArray
        latestActualTouchPoint = actualTouchPointArray.last
        return touchPoints
    }

    var hasActualValueReplacementCompleted: Bool {
        actualTouchPointArray.last?.estimationUpdateIndex == lastEstimationUpdateIndexAtCompletion
    }

    func appendEstimatedValue(_ touchPoint: CanvasTouchPoint) {
        estimatedTouchPointArray.append(touchPoint)
        updateLastEstimationUpdateIndexAtCompletionForTouchCompletion()
    }

    /// Combine `actualTouches` with the estimated values to create elements and append them to `actualTouchPointArray`
    func appendActualValueWithEstimatedValue(_ actualTouch: UITouch) {
        for i in latestEstimatedTouchArrayIndex ..< estimatedTouchPointArray.count {
            let estimatedTouchPoint = estimatedTouchPointArray[i]

            // Find the one that matches `estimationUpdateIndex`
            if actualTouch.estimationUpdateIndex == estimatedTouchPoint.estimationUpdateIndex,
               ![UITouch.Phase.ended, UITouch.Phase.cancelled].contains(estimatedTouchPoint.phase) {

                actualTouchPointArray.append(
                    .init(
                        location: estimatedTouchPoint.location,
                        phase: estimatedTouchPoint.phase,
                        force: actualTouch.force,
                        maximumPossibleForce: actualTouch.maximumPossibleForce,
                        estimationUpdateIndex: actualTouch.estimationUpdateIndex,
                        timestamp: actualTouch.timestamp
                    )
                )

                latestEstimatedTouchArrayIndex = i
            }
        }
    }

    /// Add an element with `UITouch.Phase.ended` to the end of `actualTouchPointArray`
    func appendLastEstimatedTouchPointToActualTouchPointArray() {
        guard let point = estimatedTouchPointArray.last else { return }
        actualTouchPointArray.append(point)
    }

    func updateLastEstimationUpdateIndexAtCompletionForTouchCompletion() {
        // When the touch ends, `estimationUpdateIndex` of `UITouch` becomes nil,
        // so the `estimationUpdateIndex` of the previous `UITouch` is retained.
        if [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(estimatedTouchPointArray.last?.phase) {
            lastEstimationUpdateIndexAtCompletion = estimatedTouchPointArray.dropLast().last?.estimationUpdateIndex
        }
    }

    func reset() {
        actualTouchPointArray = []
        estimatedTouchPointArray = []
        latestEstimatedTouchArrayIndex = 0
        latestActualTouchPoint = nil
        lastEstimationUpdateIndexAtCompletion = nil
        latestCanvasTouchPoint = nil
    }

}
