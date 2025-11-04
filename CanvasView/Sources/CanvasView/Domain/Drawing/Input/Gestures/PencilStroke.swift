//
//  PencilStroke.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

/// A class that manages the pen position information sent from the Apple Pencil
@MainActor final class PencilStroke {

    /// An array that stores real values.
    /// https://developer.apple.com/documentation/uikit/apple_pencil_interactions/handling_input_from_apple_pencil/
    /// The values sent from the Apple Pencil include both estimated values and real values, but only the real values are used.
    private(set) var actualTouchPointArray: [TouchPoint] = []

    /// End point of the drawing line
    private(set) var drawingLineEndPoint: TouchPoint?

    /// A variable that stores the latest estimated value, used for determining touch end
    private(set) var latestEstimatedTouchPoint: TouchPoint?

    /// A variable that stores the latest estimationUpdateIndex, used for determining touch end
    private(set) var latestEstimationUpdateIndex: NSNumber?

    init(
        actualTouchPointArray: [TouchPoint] = [],
        latestEstimatedTouchPoint: TouchPoint? = nil,
        drawingLineEndPoint: TouchPoint? = nil
    ) {
        self.actualTouchPointArray = actualTouchPointArray.sorted { $0.timestamp < $1.timestamp }
        self.latestEstimatedTouchPoint = latestEstimatedTouchPoint
        self.drawingLineEndPoint = drawingLineEndPoint
    }
}

extension PencilStroke {

    /// Gets points from the specified start element to the end
    func drawingPoints(after touchPoint: TouchPoint?) -> [TouchPoint] {
        actualTouchPointArray.elements(after: drawingLineEndPoint) ?? actualTouchPointArray
    }

    /// Stores the line endpoint
    func updateDrawingLineEndPoint() {
        if let touchPoint = actualTouchPointArray.last {
            drawingLineEndPoint = touchPoint
        }
    }

    func isPenOffScreen(actualTouches: [TouchPoint]) -> Bool {
        latestEstimatedTouchPoint?.phase == .ended &&
        actualTouches.contains(where: { $0.estimationUpdateIndex == latestEstimationUpdateIndex })
    }

    func setLatestEstimatedTouchPoint(_ estimatedTouchPoint: TouchPoint?) {
        latestEstimatedTouchPoint = estimatedTouchPoint

        if let estimationUpdateIndex = estimatedTouchPoint?.estimationUpdateIndex {
            latestEstimationUpdateIndex = estimationUpdateIndex
        }
    }

    func appendActualTouches(actualTouches: [TouchPoint]) {
        actualTouchPointArray.append(contentsOf: actualTouches)

        if isPenOffScreen(actualTouches: actualTouches),
           let latestEstimatedTouchPoint {
            self.actualTouchPointArray.append(latestEstimatedTouchPoint)
        }
    }

    func reset() {
        drawingLineEndPoint = nil

        actualTouchPointArray = []
        latestEstimatedTouchPoint = nil
        latestEstimationUpdateIndex = nil
    }
}
