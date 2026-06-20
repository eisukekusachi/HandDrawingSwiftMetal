//
//  TouchGestureState.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2025/11/09.
//

import Testing

@testable import CanvasView

@MainActor
struct FingerStrokeTests {

    private typealias Subject = FingerStroke

    @Test
    func `Verify that the values are retrieved in sequence`() {
        let touchID: TouchID = TestHelpers.makeTouchID(seed: 0)

        let firstTouches: [TouchPoint] = [
            .generate(location: .init(x: 0, y: 0), phase: .began),
            .generate(location: .init(x: 10, y: 10), phase: .moved)
        ]
        let secondTouches: [TouchPoint] = [
            .generate(location: .init(x: 20, y: 20), phase: .ended)
        ]

        let subject = Subject()

        subject.appendTouchPointToDictionary([touchID: firstTouches[0]])
        subject.appendTouchPointToDictionary([touchID: firstTouches[1]])

        #expect(subject.drawingTouchID == nil)

        // The first key of touchHistories is assigned to drawingTouchID.
        // It is assumed that touchHistories contains only one element when this method is called.
        subject.setDrawingTouchID()
        #expect(subject.drawingTouchID == touchID)

        // Gets the elements from the end point to the last element.
        let firstTouchLocations = subject.drawingPoints(after: subject.lastDrawnTouchPoint).map { $0.location }
        #expect(firstTouchLocations == firstTouches.map { $0.location })

        subject.setLastDrawnTouchPoint()

        // None are retrieved since the end point is the last element.
        #expect(subject.drawingPoints(after: subject.lastDrawnTouchPoint).map { $0.location } == [])

        subject.appendTouchPointToDictionary([touchID: secondTouches[0]])

        // Gets the elements from the end point to the last element.
        let secondTouchLocations = subject.drawingPoints(after: subject.lastDrawnTouchPoint).map { $0.location }
        #expect(secondTouchLocations == secondTouches.map { $0.location })

        subject.setLastDrawnTouchPoint()

        // None are retrieved since the end point is the last element.
        #expect(subject.drawingPoints(after: subject.lastDrawnTouchPoint).map { $0.location } == [])
    }

    @Test
    func `Verify the behavior of removeUnusedTouchArrayFromDictionary()`() {
        let subject = Subject()

        let touchID0 = TestHelpers.makeTouchID(seed: 0)
        let touchID1 = TestHelpers.makeTouchID(seed: 1)

        subject.appendTouchPointToDictionary([touchID0: .generate(phase: .began)])
        subject.appendTouchPointToDictionary([touchID1: .generate(phase: .began)])

        // No elements are removed since their touchPhase is not .ended.
        subject.removeUnusedTouchArrayFromDictionary()
        #expect(subject.touchHistories.count == 2)

        subject.appendTouchPointToDictionary([touchID0: .generate(phase: .moved)])

        // No elements are removed since their touchPhase is not .ended.
        subject.removeUnusedTouchArrayFromDictionary()
        #expect(subject.touchHistories.count == 2)

        subject.appendTouchPointToDictionary([touchID0: .generate(phase: .ended)])

        // The element is removed from the dictionary when its touchPhase is .ended.
        subject.removeUnusedTouchArrayFromDictionary()
        #expect(Set(subject.touchHistories.keys) == Set([touchID1]))

        subject.appendTouchPointToDictionary([touchID1: .generate(phase: .ended)])

        subject.removeUnusedTouchArrayFromDictionary()
        #expect(subject.touchHistories.isEmpty)
    }

    @Test
    func `Verify that hasActiveTouches remains true while at least one touch is active`() {
        let touchID0 = TestHelpers.makeTouchID(seed: 0)
        let touchID1 = TestHelpers.makeTouchID(seed: 1)
        let subject = Subject(
            touchHistories: [
                touchID0: [.generate(phase: .began)],
                touchID1: [.generate(phase: .began)]
            ]
        )

        #expect(subject.hasActiveTouches == true)

        // Still true while at least one touch has not ended/cancelled.
        subject.appendTouchPointToDictionary([touchID1: .generate(phase: .ended)])

        #expect(subject.hasActiveTouches == true)

        subject.appendTouchPointToDictionary([touchID0: .generate(phase: .ended)])
        #expect(subject.hasActiveTouches == false)
    }

    @Test
    func `Verify the behavior of reset()`() {
        let touchID0 = TestHelpers.makeTouchID(seed: 0)
        let touchPoint: TouchPoint = .generate()

        let subject = Subject(
            touchHistories: [
                touchID0: [touchPoint]
            ]
        )

        subject.setDrawingTouchID()
        subject.setLastDrawnTouchPoint()

        #expect(!subject.touchHistories.isEmpty)
        #expect(subject.drawingTouchID == touchID0)
        #expect(subject.lastDrawnTouchPoint == touchPoint)

        subject.reset()

        #expect(subject.touchHistories.isEmpty)
        #expect(subject.drawingTouchID == nil)
        #expect(subject.lastDrawnTouchPoint == nil)
    }

    @MainActor
    struct `Drawing cancellation` {
        @Test
        func `Verify that isCancelled is false when the drawing touch is not cancelled`() {
            let subject = Subject()

            let touchID = TestHelpers.makeTouchID(seed: 0)

            subject.appendTouchPointToDictionary([touchID: .generate(phase: .began)])
            subject.setDrawingTouchID()
            #expect(subject.isCancelled == false)

            subject.appendTouchPointToDictionary([touchID: .generate(phase: .moved)])
            #expect(subject.isCancelled == false)

            subject.appendTouchPointToDictionary([touchID: .generate(phase: .ended)])
            #expect(subject.isCancelled == false)
        }

        @Test
        func `Verify that isCancelled is true when the drawing touch is cancelled`() {
            let subject = Subject()
            let touchID = TestHelpers.makeTouchID(seed: 0)

            subject.appendTouchPointToDictionary([touchID: .generate(phase: .began)])
            subject.setDrawingTouchID()
            #expect(subject.isCancelled == false)

            subject.appendTouchPointToDictionary([touchID: .generate(phase: .cancelled)])
            #expect(subject.isCancelled == true)
        }
    }
}
