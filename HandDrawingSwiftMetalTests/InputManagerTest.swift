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
        let gestureManager = GestureManager()

        let fingerInput = FingerGesture(view: UIView(), delegate: nil)
        let pencilInput = PencilGesture(view: UIView(), delegate: nil)

        gestureManager.update(fingerInput)
        XCTAssertTrue(gestureManager.currentGesture is FingerGesture)

        gestureManager.update(pencilInput)
        XCTAssertTrue(gestureManager.currentGesture is PencilGesture, "The pencil input can override the finger input.")

        gestureManager.update(fingerInput)
        XCTAssertFalse(gestureManager.currentGesture is FingerGesture, "The finger input cannot override the pencil input.")

        gestureManager.clear()

        gestureManager.update(fingerInput)
        XCTAssertTrue(gestureManager.currentGesture is FingerGesture, "After resetting, the gestureManager can be updated with the finger input.")
    }
}
