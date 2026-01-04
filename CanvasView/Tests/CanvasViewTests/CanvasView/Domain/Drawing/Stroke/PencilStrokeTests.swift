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

    struct drawingPointsTests {
        @Test
        func `Retrieves elements from the array starting from the specified element`() {
            let actualTouchPoints: [TouchPoint] = [
                .generate(location: .init(x: 0, y: 0), phase: .began, estimationUpdateIndex: 0),
                .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
                .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
            ]

            let subject = Subject(actualTouchPointArray: actualTouchPoints)

            #expect(subject.drawingPoints(after: actualTouchPoints[0]) == [
                .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
                .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
            ])

            #expect(subject.drawingPoints(after: actualTouchPoints[1]) == [
                .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
            ])

            #expect(subject.drawingPoints(after: actualTouchPoints[2]) == [])
        }

        @Test
        func `Retrieves all elements from the array`() {
            let touchPointNotInArray: TouchPoint = .generate(location: .init(x: 3, y: 3), phase: .moved, estimationUpdateIndex: 3)

            let subject = Subject(actualTouchPointArray: [
                .generate(location: .init(x: 0, y: 0), phase: .began, estimationUpdateIndex: 0),
                .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
                .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
            ])

            #expect(subject.drawingPoints(after: nil) == [
                .generate(location: .init(x: 0, y: 0), phase: .began, estimationUpdateIndex: 0),
                .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
                .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
            ])

            #expect(subject.drawingPoints(after: touchPointNotInArray) == [
                .generate(location: .init(x: 0, y: 0), phase: .began, estimationUpdateIndex: 0),
                .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
                .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
            ])
        }
    }

    struct setLatestEstimatedTouchPoint {
        @Test
        func `Assigns a value to latestEstimatedTouchPoint`() {
            let subject = Subject(
                actualTouchPointArray: [
                    .generate(
                        location: .init(x: 0, y: 0),
                        phase: .began,
                        estimationUpdateIndex: 0
                    )
                ]
            )

            let estimatedTouchPoints: [TouchPoint] = [
                .generate(
                    location: .init(x: 1, y: 1),
                    phase: .moved,
                    estimationUpdateIndex: 1
                ),
                .generate(
                    location: .init(x: 2, y: 2),
                    phase: .ended,
                    estimationUpdateIndex: nil
                )
            ]

            subject.setLatestEstimatedTouchPoint(estimatedTouchPoints[0])

            #expect(subject.latestEstimatedTouchPoint == estimatedTouchPoints[0])
            // When the estimationUpdateIndex argument is not nil, the value is overwritten.
            #expect(subject.latestEstimationUpdateIndex == 1)

            subject.setLatestEstimatedTouchPoint(estimatedTouchPoints[1])

            #expect(subject.latestEstimatedTouchPoint == estimatedTouchPoints[1])
            // When the estimationUpdateIndex argument is nil, the value is not overwritten and the latest value is retained
            #expect(subject.latestEstimationUpdateIndex == 1)
        }
    }

    @Test
    func `Assigns a value to drawingLineEndPoint`() {
        let touchPoint0: TouchPoint = .generate(
            location: .init(x: 0, y: 0),
            phase: .began,
            estimationUpdateIndex: 0
        )
        let touchPoint1: TouchPoint = .generate(
            location: .init(x: 1, y: 1),
            phase: .moved,
            estimationUpdateIndex: 1
        )

        let subject = Subject(
            drawingLineEndPoint: touchPoint0
        )

        subject.appendActualTouches(actualTouches: [touchPoint1])

        // drawingLineEndPoint remains unchanged
        #expect(subject.drawingLineEndPoint == touchPoint0)

        // The last element of actualTouchPointArray is assigned to drawingLineEndPoint
        subject.setDrawingLineEndPoint()
        #expect(subject.drawingLineEndPoint == touchPoint1)
    }

    @Test
    func `Appends touchPoints to ActualTouches`() {
        let actualTouchPoint0: TouchPoint = .generate(
            location: .init(x: 0, y: 0),
            phase: .began,
            estimationUpdateIndex: 0
        )
        let actualTouchPoint1: TouchPoint = .generate(
            location: .init(x: 1, y: 1),
            phase: .moved,
            estimationUpdateIndex: 1
        )
        let actualTouchPoint2: TouchPoint = .generate(
            location: .init(x: 2, y: 2),
            phase: .moved,
            estimationUpdateIndex: 2
        )

        let estimatedTouchPoint2: TouchPoint = .generate(
            location: .init(x: 2, y: 2),
            phase: .ended,
            estimationUpdateIndex: 2
        )
        let estimatedTouchPoint3: TouchPoint = .generate(
            location: .init(x: 3, y: 3),
            phase: .ended,
            estimationUpdateIndex: nil
        )

        let subject = Subject(
            actualTouchPointArray: [
                actualTouchPoint0
            ],
            latestEstimatedTouchPoint: estimatedTouchPoint2
        )

        // Apple Pencil sends estimated values before the actual values
        subject.setLatestEstimatedTouchPoint(estimatedTouchPoint3)

        subject.appendActualTouches(actualTouches: [actualTouchPoint1])
        #expect(subject.actualTouchPointArray == [
            actualTouchPoint0, actualTouchPoint1
        ])

        // If the estimationUpdateIndex of the latest estimated value matches the estimationUpdateIndex of the latest element in actualTouches,
        // and the latest estimated value’s touchPhase is .ended,
        // the latest estimated value is added to actualTouches.
        subject.appendActualTouches(actualTouches: [actualTouchPoint2])
        #expect(subject.actualTouchPointArray == [
            actualTouchPoint0, actualTouchPoint1, actualTouchPoint2, estimatedTouchPoint3
        ])
    }

    @Test
    func `Resets the values`() {
        let actualTouchPoints: [TouchPoint] = [.generate(
            location: .init(x: 0, y: 0),
            phase: .began,
            estimationUpdateIndex: 0
        )]
        let estimatedTouchPoint: TouchPoint = .generate(
            location: .init(x: 1, y: 1),
            phase: .moved,
            estimationUpdateIndex: 1
        )
        let drawingLineEndPoint: TouchPoint = .generate(
            location: .init(x: 2, y: 2),
            phase: .ended,
            estimationUpdateIndex: 2
        )

        let subject = Subject(
            actualTouchPointArray: actualTouchPoints,
            latestEstimatedTouchPoint: estimatedTouchPoint,
            drawingLineEndPoint: drawingLineEndPoint
        )

        #expect(subject.actualTouchPointArray == actualTouchPoints)
        #expect(subject.latestEstimatedTouchPoint == estimatedTouchPoint)
        #expect(subject.latestEstimationUpdateIndex == estimatedTouchPoint.estimationUpdateIndex)
        #expect(subject.drawingLineEndPoint == drawingLineEndPoint)

        subject.reset()

        #expect(subject.actualTouchPointArray == [])
        #expect(subject.latestEstimatedTouchPoint == nil)
        #expect(subject.latestEstimationUpdateIndex == nil)
        #expect(subject.drawingLineEndPoint == nil)
    }
}
