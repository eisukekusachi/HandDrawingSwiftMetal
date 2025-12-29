//
//  TouchGestureState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/09.
//

import Testing

@testable import CanvasView

struct FingerStrokeTests {

    private typealias Subject = FingerStroke

    @Test
    func `Verify that the values are retrieved in sequence`() {
        let touchID: TouchID = 0

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
        subject.setStoreKeyForDrawing()
        #expect(subject.drawingTouchID == touchID)

        // Gets the elements from the end point to the last element.
        let firstTouchLocations = subject.drawingPoints(after: subject.drawingLineEndPoint).map { $0.location }
        #expect(firstTouchLocations == firstTouches.map { $0.location })

        subject.updateDrawingLineEndPoint()

        // None are retrieved since the end point is the last element.
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint).map { $0.location } == [])

        subject.appendTouchPointToDictionary([touchID: secondTouches[0]])

        // Gets the elements from the end point to the last element.
        let secondTouchLocations = subject.drawingPoints(after: subject.drawingLineEndPoint).map { $0.location }
        #expect(secondTouchLocations == secondTouches.map { $0.location })

        subject.updateDrawingLineEndPoint()

        // None are retrieved since the end point is the last element.
        #expect(subject.drawingPoints(after: subject.drawingLineEndPoint).map { $0.location } == [])
    }

    @Test
    func `Verify the behavior of removeEndedTouchArrayFromDictionary()`() {
        let subject = Subject()

        subject.appendTouchPointToDictionary([0: .generate(phase: .began)])
        subject.appendTouchPointToDictionary([1: .generate(phase: .began)])

        // No elements are removed since their touchPhase is not .eneded.
        subject.removeEndedTouchArrayFromDictionary()
        #expect(subject.touchHistories.count == 2)

        subject.appendTouchPointToDictionary([0: .generate(phase: .moved)])

        // No elements are removed since their touchPhase is not .eneded.
        subject.removeEndedTouchArrayFromDictionary()
        #expect(subject.touchHistories.count == 2)

        subject.appendTouchPointToDictionary([0: .generate(phase: .ended)])

        // The element is removed from the dictionary when its touchPhase is .ended.
        subject.removeEndedTouchArrayFromDictionary()
        #expect(subject.touchHistories.keys.sorted() == [1])

        subject.appendTouchPointToDictionary([1: .generate(phase: .ended)])

        subject.removeEndedTouchArrayFromDictionary()
        #expect(subject.touchHistories.isEmpty == true)
    }

    @Test
    func `Verify the behavior of hasEndedTouches`() {
        let subject = Subject(
            touchHistories: [
                0: [.generate(phase: .began)],
                1: [.generate(phase: .began)]
            ]
        )

        #expect(subject.hasEndedTouches == false)

        // Returns true if at least one element in the dictionary has its touchPhase set to .ended.
        subject.appendTouchPointToDictionary([1: .generate(phase: .ended)])

        #expect(subject.hasEndedTouches == true)
    }

    @Test
    func `Verify the behavior of reset()`() {
        let touchPoint: TouchPoint = .generate()

        let subject = Subject(
            touchHistories: [
                0: [touchPoint]
            ]
        )

        subject.setStoreKeyForDrawing()
        subject.updateDrawingLineEndPoint()

        #expect(subject.touchHistories.isEmpty == false)
        #expect(subject.drawingTouchID == 0)
        #expect(subject.drawingLineEndPoint == touchPoint)

        subject.reset()

        #expect(subject.touchHistories.isEmpty == true)
        #expect(subject.drawingTouchID == nil)
        #expect(subject.drawingLineEndPoint == nil)
    }
}
