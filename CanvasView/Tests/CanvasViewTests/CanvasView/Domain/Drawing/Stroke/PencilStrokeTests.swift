//
//  PencilStrokeTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/09.
//

import Testing

@testable import CanvasView

struct PencilStrokeTests {

    private typealias Subject = PencilStroke

    @Test
    func `Verify that the values are retrieved in sequence`() {
        let subject = Subject()

        let firstActualTouches: [TouchPoint] = [
            .generate(location: .init(x: 0, y: 0), phase: .began, estimationUpdateIndex: 0)
        ]
        let secondActualTouches: [TouchPoint] = [
            .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
            .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
        ]
        let thirdActualTouches: [TouchPoint] = [
            .generate(location: .init(x: 3, y: 3), phase: .moved, estimationUpdateIndex: 3)
        ]

        let thirdEstimatedTouch: TouchPoint = .generate(location: .init(x: 3, y: 3), phase: .moved, estimationUpdateIndex: 3)
        let fourthEstimatedTouch: TouchPoint = .generate(location: .init(x: 4, y: 4), phase: .ended, estimationUpdateIndex: nil)

        subject.appendActualTouches(
            actualTouches: firstActualTouches
        )

        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint) == firstActualTouches)

        subject.updateDrawingLineEndPoint()
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint).isEmpty)

        subject.appendActualTouches(
            actualTouches: secondActualTouches
        )

        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint) == secondActualTouches)

        subject.updateDrawingLineEndPoint()
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint).isEmpty)

        subject.setLatestEstimatedTouchPoint(thirdEstimatedTouch)
        subject.setLatestEstimatedTouchPoint(fourthEstimatedTouch)

        subject.appendActualTouches(
            actualTouches: thirdActualTouches
        )

        // Since an actual touch never arrives with a phase of .ended, a estimated value is used for the final touch
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint) ==  thirdActualTouches + [fourthEstimatedTouch])
    }
}
