//
//  SmoothPointIteratorTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class SmoothPointIteratorTest: XCTestCase {

    // Create a new iterator that calculates the average value from an iterator and perform a test to verify its value
    func testSmoothIterator() {
        let range = 4

        let inputs: [TouchPoint] = [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
            .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
            .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5)
        ]

        let results: [[TouchPoint]] = [
            [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0), // Use the first point.
            .init(location: CGPoint(x: 5, y: 5), alpha: 0.05), // Use the value of the average.
            .init(location: CGPoint(x: 15, y: 15), alpha: 0.15),
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25)
            ],
            [
            .init(location: CGPoint(x: 5, y: 5), alpha: 0.05),
            .init(location: CGPoint(x: 15, y: 15), alpha: 0.15),
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25),
            .init(location: CGPoint(x: 35, y: 35), alpha: 0.35)
            ],
            [
            .init(location: CGPoint(x: 15, y: 15), alpha: 0.15),
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25),
            .init(location: CGPoint(x: 35, y: 35), alpha: 0.35),
            .init(location: CGPoint(x: 45, y: 45), alpha: 0.45)
            ],
            [
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25),
            .init(location: CGPoint(x: 35, y: 35), alpha: 0.35),
            .init(location: CGPoint(x: 45, y: 45), alpha: 0.45), // Use the value of the average.
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5) // Use the last point.
            ]
        ]

        let iterator = Iterator<TouchPoint>()
        var smoothIterator = Iterator<TouchPoint>()

        iterator.update(elems: inputs)
        SmoothTouchPointStorage.makeIterator(src: iterator,
                                             dst: &smoothIterator,
                                             endProcessing: true)

        var count: Int = 0
        while let subsequece = smoothIterator.next(range: range) {
            XCTAssertEqual([TouchPoint(location: subsequece[0].location,
                                       alpha: round(subsequece[0].alpha * 100) / 100),

                            TouchPoint(location: subsequece[1].location,
                                       alpha: round(subsequece[1].alpha * 100) / 100),

                            TouchPoint(location: subsequece[2].location,
                                       alpha: round(subsequece[2].alpha * 100) / 100),

                            TouchPoint(location: subsequece[3].location,
                                       alpha: round(subsequece[3].alpha * 100) / 100)],

                           results[count])
            count += 1
        }

        XCTAssertEqual(count, results.count, "Executed 4 times.")
    }
}
