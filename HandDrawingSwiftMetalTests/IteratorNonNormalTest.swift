//
//  IteratorNonNormalTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class IteratorNonNormalTest: XCTestCase {

    let inputs: [TouchPoint] = [
        .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
        .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
        .init(location: CGPoint(x: 20, y: 20), alpha: 0.2)
    ]

    func testIteratorNonNormalSenarios() {
        XCTContext.runActivity(named: "A scenario with input 0") { _ in
            let iterator = Iterator<TouchPoint>()

            iterator.update(elems: inputs)

            XCTAssertEqual(iterator.array.count, inputs.count)

            var notPassThroughBlock = true
            while let _ = iterator.next(range: 0) {
                notPassThroughBlock = false
            }
            XCTAssertTrue(notPassThroughBlock, 
                          "Because the range is 0.")
        }

        XCTContext.runActivity(named: "A scenario with input 4") { _ in
            let iterator = Iterator<TouchPoint>()

            iterator.update(elems: inputs)

            XCTAssertEqual(iterator.array.count, inputs.count)

            var notPassThroughBlock = true
            while let _ = iterator.next(range: 4) {
                notPassThroughBlock = false
            }
            XCTAssertTrue(notPassThroughBlock, 
                          "Because the range is greater than the number of array elements.")
        }
    }
}
