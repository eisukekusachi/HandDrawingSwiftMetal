//
//  GestureManagerTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/04/04.
//

import XCTest
@testable import HandDrawingSwiftMetal

class InputManagerTest: XCTestCase {
    
    func testInputManager() {
        
        XCTContext.runActivity(named: "A scenario that the pencil input is stronger than the finger input") { _ in
            // Because sometimes a user draw a line with an Apple Pencil during user’s palm is on a screen.
            
            let inputManager = InputManager()
            
            let fingerInput = FingerGestureRecognizer()
            let pencilInput = PencilGestureRecognizer()
            
            inputManager.update(fingerInput)
            XCTAssertTrue(inputManager.currentInput is FingerGestureRecognizer)
            
            
            inputManager.update(pencilInput)
            XCTAssertTrue(inputManager.currentInput is PencilGestureRecognizer, "The pencil input can override the finger input.")
            
            inputManager.update(fingerInput)
            XCTAssertFalse(inputManager.currentInput is FingerGestureRecognizer, "The finger input cannot override the pencil input.")
            
            
            inputManager.reset()
            
            inputManager.update(fingerInput)
            XCTAssertTrue(inputManager.currentInput is FingerGestureRecognizer, "After resetting, the gestureManager can be updated with the finger input.")
        }
    }
}
