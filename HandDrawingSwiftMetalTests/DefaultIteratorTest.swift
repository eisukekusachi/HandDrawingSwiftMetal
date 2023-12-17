//
//  DefaultIteratorTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class DefaultIteratorTest: XCTestCase {
    
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

        var index = 0
        while let subsequece = iterator.next(range: range) {
            if index == 0 {
                XCTAssertTrue(iterator.isFirstProcessing)
            }

            let value = subsequece[0]
            XCTAssertEqual(value, inputs[index])
            XCTAssertEqual(subsequece.count, range)

            index += 1
        }
    }
}
