//
//  DrawingIteratorTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class DrawingIteratorTest: XCTestCase {
    let finger3Inputs: [TouchPoint] = [
        .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
        .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
        .init(location: CGPoint(x: 20, y: 20), alpha: 0.2)
    ]
    let finger1Inputs: [TouchPoint] = [
        .init(location: CGPoint(x: 30, y: 30), alpha: 0.3)
    ]
    let finger6Inputs: [TouchPoint] = [
        .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
        .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
        .init(location: CGPoint(x: 60, y: 60), alpha: 0.6),
        .init(location: CGPoint(x: 70, y: 70), alpha: 0.7),
        .init(location: CGPoint(x: 80, y: 80), alpha: 0.8)
    ]

    let results: [[TouchPoint]] = [
        [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
            .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3)
        ],
        [
            .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
            .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
            .init(location: CGPoint(x: 40, y: 40), alpha: 0.4)
        ],
        [
            .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
            .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5)
        ],
        [
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
            .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
            .init(location: CGPoint(x: 60, y: 60), alpha: 0.6)
        ],
        [
            .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
            .init(location: CGPoint(x: 60, y: 60), alpha: 0.6),
            .init(location: CGPoint(x: 70, y: 70), alpha: 0.7)
        ],
        [
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
            .init(location: CGPoint(x: 60, y: 60), alpha: 0.6),
            .init(location: CGPoint(x: 70, y: 70), alpha: 0.7),
            .init(location: CGPoint(x: 80, y: 80), alpha: 0.8)
        ]
    ]

    func testIteratorWithRange4() {
        let range: Int = 4

        let iterator = Iterator<TouchPoint>()
        var fingerInputArray: [TouchPoint] = []

        fingerInputArray.append(contentsOf: finger3Inputs)
        iterator.update(elems: fingerInputArray)
        XCTAssertEqual(iterator.array.count, 3)

        fingerInputArray.append(contentsOf: finger1Inputs)
        iterator.update(elems: fingerInputArray)
        XCTAssertEqual(iterator.array.count, 4)

        fingerInputArray.append(contentsOf: finger6Inputs)
        iterator.update(elems: fingerInputArray)
        XCTAssertEqual(iterator.array.count, 9)

        var count = 0
        while let subsequece = iterator.next(range: range) {

            XCTAssertEqual(subsequece.count, range)

            XCTAssertEqual(subsequece[0], results[count][0])
            XCTAssertEqual(subsequece[1], results[count][1])
            XCTAssertEqual(subsequece[2], results[count][2])
            XCTAssertEqual(subsequece[3], results[count][3])

            count += 1
        }
        XCTAssertEqual(count, results.count, "Executed 6 times.")
    }
}
