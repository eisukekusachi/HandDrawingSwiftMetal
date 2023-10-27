//
//  ActionStateTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/04/03.
//

import XCTest
@testable import HandDrawingSwiftMetal

class ActionStateTest: XCTestCase {    

    // when the actionState is determined once, it cannot be changed until reset.
    func testActionState() {

        XCTAssertEqual(ActionState.activatingDrawingCount, 5)

        // Set the number of arrays to count + 1
        let firstInputs: [TouchPoint] = [
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0)
        ]
        let secondInputs: [TouchPoint] = [
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0),
            .init(location: .zero, alpha: 0.0)
        ]

        var oneFingerInputArrayDictionary: [Int: [TouchPoint]] = [:]
        var twoFingerInputArrayDictionary: [Int: [TouchPoint]] = [:]

        // Add the array and update to determine the action
        oneFingerInputArrayDictionary[0] = firstInputs
        let oneFingerActionState = ActionStateManager.getState(oneFingerInputArrayDictionary)

        // Add the array and update to determine the action
        twoFingerInputArrayDictionary[0] = firstInputs
        twoFingerInputArrayDictionary[1] = secondInputs
        let twoFingerActionState = ActionStateManager.getState(twoFingerInputArrayDictionary)


        let actionStateManager = ActionStateManager()

        actionStateManager.updateState(oneFingerActionState)
        XCTAssertEqual(actionStateManager.state, .drawingOnCanvas)


        actionStateManager.updateState(twoFingerActionState)
        XCTAssertNotEqual(actionStateManager.state, .transformingCanvas, "The actionState cannot be changed until reset.")

        actionStateManager.reset()

        actionStateManager.updateState(twoFingerActionState)
        XCTAssertEqual(actionStateManager.state, .transformingCanvas, "After resetting, the actionState can be changed.")
    }
}
