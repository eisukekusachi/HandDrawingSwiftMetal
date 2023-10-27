//
//  DefaultIteratorTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/10/20.
//

import XCTest
@testable import HandDrawingSwiftMetal

class DefaultIIteratorTest: XCTestCase {

    func testDefaultIteratorSenarios() {
        let range = 1

        let inputs: [TouchPoint] = [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
            .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3)
        ]

        let iterator = Iterator<TouchPoint>()
        iterator.update(elems: inputs)

        var count = 0
        while let subsequece = iterator.next(range: range) {
            if count == 0 {
                XCTAssertTrue(iterator.isFirstProcessing)
            }

            XCTAssertEqual(subsequece.count, range)

            XCTAssertEqual(subsequece[0], inputs[count + 0])

            count += 1
        }
    }
}
