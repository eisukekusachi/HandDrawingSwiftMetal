//
//  DrawingDisplayLinkTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/05.
//

import CanvasView
import XCTest
import Combine

@testable import CanvasView

final class DrawingDisplayLinkTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    private typealias Subject = DrawingDisplayLink

    /// Verifies that the display link starts and `updatePublisher` begins emitting values.
    func test_updatePublisherEmits_whenDisplayLinkStarts() throws {
        let subject = Subject()

        let expectation = XCTestExpectation(description: "updatePublisher emits at least once")

        subject.updatePublisher
            .sink { expectation.fulfill() }
            .store(in: &cancellables)

        subject.run(true)

        XCTAssertEqual(subject.displayLink?.isPaused, false)

        wait(for: [expectation], timeout: 1.0)
    }

    /// Verifies that the display link stops and `updatePublisher` emits `Void` once.
    func test_updatePublisherEmitsOnce_whenDisplayLinkStops() throws {
        let subject = Subject()

        let expectation = XCTestExpectation(description: "updatePublisher emits once")
        expectation.expectedFulfillmentCount = 1

        subject.updatePublisher
            .sink { expectation.fulfill() }
            .store(in: &cancellables)

        subject.run(false)

        XCTAssertEqual(subject.displayLink?.isPaused, true)

        wait(for: [expectation], timeout: 1.0)
    }

    /// Verifies that when `stop()` is called, the display link stops and `updateCanvasWhileDrawing()` is not executed.
    func test_updateCanvasNotExecuted_whenStopped() {
        let subject = DrawingDisplayLink()

        let expectation = XCTestExpectation(description: "`updatePublisher` should not emit")
        expectation.isInverted = true

        subject.updatePublisher
            .sink { expectation.fulfill() }
            .store(in: &cancellables)

        subject.stop()

        XCTAssertEqual(subject.displayLink?.isPaused, true)

        wait(for: [expectation], timeout: 1.0)
    }
}
