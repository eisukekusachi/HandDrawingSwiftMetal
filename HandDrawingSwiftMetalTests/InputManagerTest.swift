//
//  GestureManagerTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/04/04.
//

import XCTest
@testable import HandDrawingSwiftMetal

class InputManagerTest: XCTestCase {

    // When pen input is used, finger input is canceled
    // because sometimes a user draw a line with an Apple Pencil during user’s palm is on a screen.
    func testInputManager() {
        let inputManager = InputManager()

        let fingerInput = FingerInput(view: UIView(), delegate: nil)
        let pencilInput = PencilInput(view: UIView(), delegate: nil)

        inputManager.updateInput(fingerInput)
        XCTAssertTrue(inputManager.currentInput is FingerInput)

        inputManager.updateInput(pencilInput)
        XCTAssertTrue(inputManager.currentInput is PencilInput, "The pencil input can override the finger input.")

        inputManager.updateInput(fingerInput)
        XCTAssertFalse(inputManager.currentInput is FingerInput, "The finger input cannot override the pencil input.")

        inputManager.clear()

        inputManager.updateInput(fingerInput)
        XCTAssertTrue(inputManager.currentInput is FingerInput, "After resetting, the gestureManager can be updated with the finger input.")
    }
}
