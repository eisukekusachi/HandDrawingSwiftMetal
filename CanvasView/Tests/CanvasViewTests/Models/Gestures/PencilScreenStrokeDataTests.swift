//
//  PencilStrokeTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/09.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class PencilStrokeTests: XCTestCase {
    /// Confirms pencil input
    @MainActor
    func testActualTouchPointArray() {
        let subject = PencilStroke()

        subject.appendActualTouches(actualTouches: [
            .generate(location: .init(x: 0, y: 0), phase: .began, estimationUpdateIndex: 0)
        ])

        XCTAssertEqual(
            subject.latestActualTouchPoints.map { $0.location },
            [
                .init(x: 0, y: 0)
            ]
        )

        // After `latestTouchPoints` is called once, it returns empty.
        XCTAssertEqual(subject.latestActualTouchPoints, [])

        subject.appendActualTouches(actualTouches: [
            .generate(location: .init(x: 1, y: 1), phase: .moved, estimationUpdateIndex: 1),
            .generate(location: .init(x: 2, y: 2), phase: .moved, estimationUpdateIndex: 2)
        ])

        XCTAssertEqual(
            subject.latestActualTouchPoints.map { $0.location },
            [
                .init(x: 1, y: 1),
                .init(x: 2, y: 2)
            ]
        )

        subject.setLatestEstimatedTouchPoint(
            .generate(location: .init(x: 3, y: 3), phase: .moved, estimationUpdateIndex: 3)
        )
        subject.setLatestEstimatedTouchPoint(
            .generate(location: .init(x: 4, y: 4), phase: .ended, estimationUpdateIndex: nil)
        )

        // When values are sent from the Apple Pencil,
        // when the `phase` is `ended`, `estimationUpdateIndex` becomes `nil`,
        // so the previous `estimationUpdateIndex` is retained.
        XCTAssertEqual(subject.latestEstimationUpdateIndex, 3)
        XCTAssertEqual(subject.latestEstimatedTouchPoint?.phase, .ended)

        // Since the phase of `actualTouches` does not become `ended`,
        // the pen is considered to have left
        // when `latestEstimatedTouchPoint?.phase` is `ended`,
        // `latestEstimationUpdateIndex` matches the `estimationUpdateIndex` of `actualTouches`.
        subject.appendActualTouches(actualTouches: [
            .generate(location: .init(x: 3, y: 3), phase: .moved, estimationUpdateIndex: 3)
        ])

        // When the pen leaves the screen,
        // `latestEstimatedTouchPoint` is added to `actualTouchPointArray`,
        // and the drawing termination process is executed.
        XCTAssertEqual(
            subject.latestActualTouchPoints.map { $0.location },
            [
                .init(x: 3, y: 3),
                .init(x: 4, y: 4)
            ]
        )
    }

    /// Confirms that a pen has left the screen
    @MainActor
    func testIsPenOffScreen() {
        let subject = PencilStroke()

        let actualTouches: [TouchPoint] = [
            .generate(phase: .moved, estimationUpdateIndex: 1)
        ]

        subject.setLatestEstimatedTouchPoint(
            .generate(phase: .moved, estimationUpdateIndex: 1)
        )
        XCTAssertEqual(subject.latestEstimatedTouchPoint?.phase, .moved)
        XCTAssertEqual(subject.latestEstimationUpdateIndex, 1)

        XCTAssertFalse(subject.isPenOffScreen(actualTouches: actualTouches))

        // If `latestEstimatedTouchPoint?.phase` is `ended`,
        // `latestEstimationUpdateIndex` matches the `estimationUpdateIndex` of `actualTouches`,
        // then `isPenOffScreen` returns `true`.
        subject.setLatestEstimatedTouchPoint(
            .generate(phase: .ended, estimationUpdateIndex: nil)
        )
        XCTAssertEqual(subject.latestEstimatedTouchPoint?.phase, .ended)
        XCTAssertEqual(subject.latestEstimationUpdateIndex, actualTouches.last?.estimationUpdateIndex)

        XCTAssertTrue(subject.isPenOffScreen(actualTouches: actualTouches))
    }

    @MainActor
    func testReset() {
        let subject = PencilStroke(
            actualTouchPointArray: [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 1, y: 1))
            ],
            latestEstimatedTouchPoint: .generate(location: .init(x: 2, y: 2)),
            latestActualTouchPoint: .generate(location: .init(x: 3, y: 3))
        )

        XCTAssertFalse(subject.actualTouchPointArray.isEmpty)
        XCTAssertNotNil(subject.latestEstimatedTouchPoint)
        XCTAssertNotNil(subject.latestActualTouchPoint)

        subject.reset()

        XCTAssertTrue(subject.actualTouchPointArray.isEmpty)
        XCTAssertNil(subject.latestEstimatedTouchPoint)
        XCTAssertNil(subject.latestActualTouchPoint)
    }
}
