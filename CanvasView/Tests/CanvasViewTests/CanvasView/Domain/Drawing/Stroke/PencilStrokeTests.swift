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
    func `Retrieves values in sequence`() {
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

        subject.setDrawingLineEndPoint()
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint).isEmpty)

        subject.appendActualTouches(
            actualTouches: secondActualTouches
        )

        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint) == secondActualTouches)

        subject.setDrawingLineEndPoint()
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint).isEmpty)

        subject.setLatestEstimatedTouchPoint(thirdEstimatedTouch)
        subject.setLatestEstimatedTouchPoint(fourthEstimatedTouch)

        subject.appendActualTouches(
            actualTouches: thirdActualTouches
        )

        // It appears that an actual touch does not include an `.ended` phase,
        // so an estimated value with the `.ended` phase is added at the end.
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint) ==  thirdActualTouches + [fourthEstimatedTouch])
    }
}
