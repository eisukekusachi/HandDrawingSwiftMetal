//
//  ActionStateTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class ActionStateTest: XCTestCase {
    
    // When the actionState is determined once, it cannot be changed until reset.
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

        // Add an array and determine the action state
        oneFingerInputArrayDictionary[0] = firstInputs
        let oneFingerActionState = ActionStateManager.getState(oneFingerInputArrayDictionary)

        // Add an array and determine the action state
        twoFingerInputArrayDictionary[0] = firstInputs
        twoFingerInputArrayDictionary[1] = secondInputs
        let twoFingerActionState = ActionStateManager.getState(twoFingerInputArrayDictionary)


        let actionStateManager = ActionStateManager()

        actionStateManager.updateState(oneFingerActionState)
        XCTAssertEqual(actionStateManager.state, .drawing)


        actionStateManager.updateState(twoFingerActionState)
        XCTAssertNotEqual(actionStateManager.state, .transforming,
                          "The actionState cannot be changed until reset.")

        actionStateManager.reset()

        actionStateManager.updateState(twoFingerActionState)
        XCTAssertEqual(actionStateManager.state, .transforming, 
                       "After resetting, the actionState can be changed.")
    }
}
