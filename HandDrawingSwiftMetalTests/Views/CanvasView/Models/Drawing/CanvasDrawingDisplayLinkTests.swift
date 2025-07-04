//
//  CanvasDrawingDisplayLinkTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/02/05.
//

import XCTest
import Combine
@testable import HandDrawingSwiftMetal

final class CanvasDrawingDisplayLinkTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    /// Confirms that the displayLink is running and `canvasDrawingPublisher` emits `Void`
    func testEmitRequestDrawingOnCanvasPublisherWhenTouchingScreen() {
        let subject = CanvasDrawingDisplayLink()

        let publisherExpectation = XCTestExpectation()

        // Confirm that `canvasDrawingPublisher` emits `Void`
        subject.canvasDrawingPublisher
            .sink {
                publisherExpectation.fulfill()
            }
            .store(in: &cancellables)

        subject.run(true)

        XCTAssertEqual(subject.displayLink?.isPaused, false)

        wait(for: [publisherExpectation], timeout: 1.0)
    }

    /// Confirms that the displayLink stops and `canvasDrawingPublisher` emits `Void` once
    func testEmitRequestDrawingOnCanvasPublisherWhenFingerIsLifted() {
        let subject = CanvasDrawingDisplayLink()

        let publisherExpectation = XCTestExpectation()

        // `canvasDrawingPublisher` emits `Void` to perform the final processing
        subject.canvasDrawingPublisher
            .sink {
                publisherExpectation.fulfill()
            }
            .store(in: &cancellables)

        subject.run(false)

        XCTAssertEqual(subject.displayLink?.isPaused, true)

        wait(for: [publisherExpectation], timeout: 1.0)
    }

}
