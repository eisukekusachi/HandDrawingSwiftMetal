//
//  TransformingActionStateTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/10/24.
//

import XCTest
@testable import HandDrawingSwiftMetal

class TransformingActionStateTest: XCTest {

    // A continuous two-finger input determines the actionState as transforming.
    func testActionState() {

        XCTAssertEqual(ActionState.activatingTransformingCount, 3)

        let firstFinger3Inputs: [TouchPoint] = [
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0)
        ]
        let firstFinger1Inputs: [TouchPoint] = [
            .init(location: .zero, alpha: 0.0)
        ]

        let secondFinger1Inputs: [TouchPoint] = [
            .init(location: .zero, alpha: 0.0)
        ]
        let secondFinger3Inputs: [TouchPoint] = [
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0)
        ]

        var inputArrayDictionary: [Int: [TouchPoint]] = [:]

        // Set the first finger data to the array.
        inputArrayDictionary[0] = firstFinger3Inputs
        XCTAssertEqual(ActionStateManager.getState(touchPoints: inputArrayDictionary), ActionState.recognizing)

        // Set the second finger data to the array.
        inputArrayDictionary[1] = secondFinger1Inputs
        XCTAssertEqual(ActionStateManager.getState(touchPoints: inputArrayDictionary), ActionState.recognizing)

        // Add the first finger data to the array.
        inputArrayDictionary[0]?.append(contentsOf: firstFinger1Inputs)
        XCTAssertEqual(ActionStateManager.getState(touchPoints: inputArrayDictionary), ActionState.recognizing)

        // Add the second finger data to the array.
        inputArrayDictionary[1]?.append(contentsOf: secondFinger3Inputs)
        XCTAssertEqual(ActionStateManager.getState(touchPoints: inputArrayDictionary), ActionState.transformingCanvas)
    }
}
