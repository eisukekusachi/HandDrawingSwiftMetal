//
//  DrawingActionStateTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/10/24.
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
        let finger1Inputs: [TouchPoint] = [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
        ]

        var inputArrayDictionary: [Int: [TouchPoint]] = [:]

        inputArrayDictionary[0] = finger5Inputs
        let actionState0 = ActionStateManager.getState(touchPoints: inputArrayDictionary)
        XCTAssertEqual(actionState0, ActionState.recognizing)

        inputArrayDictionary[0]?.append(contentsOf: finger1Inputs)

        // The actionState is determined.
        let actionState1 = ActionStateManager.getState(touchPoints: inputArrayDictionary)
        XCTAssertEqual(actionState1, ActionState.drawingOnCanvas)
    }
}
