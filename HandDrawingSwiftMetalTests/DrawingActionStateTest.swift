//
//  DrawingActionStateTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class DrawingActionStateTest: XCTest {

    // A continuous one-finger input determines the actionState as drawing.
    func testActionState() {

        XCTAssertEqual(ActionState.activatingDrawingCount, 5)

        let finger5Inputs: [TouchPoint] = [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
        ]
        let nextInputs: [TouchPoint] = [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
        ]

        var inputArrayDictionary: [Int: [TouchPoint]] = [:]

        inputArrayDictionary[0] = finger5Inputs
        let actionState0 = ActionStateManager.getState(inputArrayDictionary)
        XCTAssertEqual(actionState0, ActionState.recognizing)

        inputArrayDictionary[0]?.append(contentsOf: nextInputs)

        // The actionState is determined.
        let actionState1 = ActionStateManager.getState(inputArrayDictionary)
        XCTAssertEqual(actionState1, .drawing)
    }
}
