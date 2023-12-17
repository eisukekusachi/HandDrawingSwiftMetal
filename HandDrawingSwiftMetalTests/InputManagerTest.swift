//
//  InputManagerTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class InputManagerTest: XCTestCase {

    // When pen input is used, finger input is canceled
    // because sometimes a user draw a line with an Apple Pencil during user’s palm is on a screen.
    func testInputManager() {
        let inputManager = InputManager()

        let fingerInput = FingerGestureWithStorage(view: UIView(), delegate: nil)
        let pencilInput = PencilGestureWithStorage(view: UIView(), delegate: nil)

        inputManager.updateInput(fingerInput)
        XCTAssertTrue(inputManager.currentInput is FingerGestureWithStorage)

        inputManager.updateInput(pencilInput)
        XCTAssertTrue(inputManager.currentInput is PencilGestureWithStorage, 
                      "The pencil input can override the finger input.")

        inputManager.updateInput(fingerInput)
        XCTAssertFalse(inputManager.currentInput is FingerGestureWithStorage, 
                       "The finger input cannot override the pencil input.")

        inputManager.clear()

        inputManager.updateInput(fingerInput)
        XCTAssertTrue(inputManager.currentInput is FingerGestureWithStorage,
                      "After resetting, the gestureManager can be updated with the finger input.")
    }
}
