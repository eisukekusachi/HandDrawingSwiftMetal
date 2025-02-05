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
    var commandBuffer: MTLCommandBuffer!
    let device = MTLCreateSystemDefaultDevice()!

    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
    }

    /// Confirms that the displayLink is running and `requestDrawingOnCanvasPublisher` emits `Void`
    func testEmitRequestDrawingOnCanvasPublisherWhenTouchingScreen() {
        let subject = CanvasDrawingDisplayLink()

        let publisherExpectation = XCTestExpectation()

        // Confirm that `requestDrawingOnCanvasPublisher` emits `Void`
        subject.requestDrawingOnCanvasPublisher
            .sink {
                publisherExpectation.fulfill()
            }
            .store(in: &cancellables)

        subject.runDisplayLink(isCurrentlyDrawing: true)

        XCTAssertEqual(subject.displayLink?.isPaused, false)

        wait(for: [publisherExpectation], timeout: 1.0)
    }

    /// Confirms that the displayLink stops and `requestDrawingOnCanvasPublisher` emits `Void` once
    func testEmitRequestDrawingOnCanvasPublisherWhenFingerIsLifted() {
        let subject = CanvasDrawingDisplayLink()

        let publisherExpectation = XCTestExpectation()

        // `requestDrawingOnCanvasPublisher` emits `Void` to perform the final processing
        subject.requestDrawingOnCanvasPublisher
            .sink {
                publisherExpectation.fulfill()
            }
            .store(in: &cancellables)

        subject.runDisplayLink(isCurrentlyDrawing: false)

        XCTAssertEqual(subject.displayLink?.isPaused, true)

        wait(for: [publisherExpectation], timeout: 1.0)
    }

}
