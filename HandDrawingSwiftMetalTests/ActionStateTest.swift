//
//  ActionStateTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/04/03.
//

import XCTest
@testable import HandDrawingSwiftMetal

class ActionStateTest: XCTestCase {
    
    func testActionDrawingState() {
        
        // A continuous one-finger input determines the actionState as drawing.
        XCTContext.runActivity(named: "A scenario for drawing") { _ in
            
            let fingerLocations0: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            let fingerLocations1: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            
            var viewTouchesForTesting: [Int: [Point]] = [:]
            
            // Set the finger data to the array.
            viewTouchesForTesting[0] = fingerLocations0
            
            XCTAssertEqual(ActionState.activatingDrawingCount, 5)
            XCTAssertEqual(viewTouchesForTesting[0]?.count, 5)
            
            XCTAssertEqual(ActionState.getCurrentState(viewTouches: viewTouchesForTesting), ActionState.recognizing)
            
            // Add the finger data to the array.
            viewTouchesForTesting[0]?.append(contentsOf: fingerLocations1)
            
            
            // The actionState is determined.
            XCTAssertEqual(ActionState.activatingDrawingCount, 5)
            XCTAssertEqual(viewTouchesForTesting[0]?.count, 6, "The number of elements exceeds the count.")
            
            XCTAssertEqual(ActionState.getCurrentState(viewTouches: viewTouchesForTesting), ActionState.drawingOnCanvas)
        }
    }
    
    func testActionTransformingState() {
        
        // A continuous two-finger input determines the actionState as transforming.
        XCTContext.runActivity(named: "A scenario for transforming") { _ in
            
            let firstFingerLocations0: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            let firstFingerLocations1: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            
            let secondFingerLocations0: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            let secondFingerLocations1: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            
            
            var viewTouchesForTesting: [Int: [Point]] = [:]
            
            
            // Set the first finger data to the array.
            viewTouchesForTesting[0] = firstFingerLocations0
            
            XCTAssertEqual(viewTouchesForTesting[0]?.count, 3)
            
            XCTAssertEqual(ActionState.getCurrentState(viewTouches: viewTouchesForTesting), ActionState.recognizing)
            
            
            // Set the second finger data to the array.
            viewTouchesForTesting[1] = secondFingerLocations0
            
            XCTAssertEqual(ActionState.activatingTransformingCount, 3)
            XCTAssertEqual(viewTouchesForTesting[0]?.count, 3)
            XCTAssertEqual(viewTouchesForTesting[1]?.count, 3)
            
            XCTAssertEqual(ActionState.getCurrentState(viewTouches: viewTouchesForTesting), ActionState.recognizing)
            
            
            // Add the first finger data to the array.
            viewTouchesForTesting[0]?.append(contentsOf: firstFingerLocations1)
            
            XCTAssertEqual(ActionState.activatingTransformingCount, 3)
            XCTAssertEqual(viewTouchesForTesting[0]?.count, 4)
            XCTAssertEqual(viewTouchesForTesting[1]?.count, 3)
            
            XCTAssertEqual(ActionState.getCurrentState(viewTouches: viewTouchesForTesting), ActionState.recognizing)
            
            
            // Add the second finger data to the array.
            viewTouchesForTesting[1]?.append(contentsOf: secondFingerLocations1)
            
            
            // The actionState is determined.
            XCTAssertEqual(ActionState.activatingTransformingCount, 3)
            XCTAssertEqual(viewTouchesForTesting[0]?.count, 4, "The number of elements exceeds the count.")
            XCTAssertEqual(viewTouchesForTesting[1]?.count, 4, "The number of elements exceeds the count.")
            
            XCTAssertEqual(ActionState.getCurrentState(viewTouches: viewTouchesForTesting), ActionState.transformingCanvas)
        }
    }
    
    func testActionStateManager() {
        
        XCTContext.runActivity(named: "A scenario that when the actionState is determined once, it cannot be changed until reset.") { _ in
            
            let actionStateManager = ActionStateManager()
            
            let firstFingerLocations: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            let secondFingerLocations: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0)
            ]
            
            var viewTouchesForTesting: [Int: [Point]] = [:]
            
            viewTouchesForTesting[0] = firstFingerLocations
            
            actionStateManager.update(ActionState.getCurrentState(viewTouches: viewTouchesForTesting))
            XCTAssertEqual(actionStateManager.currentState, .drawingOnCanvas)
            
            viewTouchesForTesting[1] = secondFingerLocations
            
            actionStateManager.update(ActionState.getCurrentState(viewTouches: viewTouchesForTesting))
            XCTAssertEqual(actionStateManager.currentState, .drawingOnCanvas, "The actionState cannot be changed until reset.")
            
            actionStateManager.reset()
            
            actionStateManager.update(ActionState.getCurrentState(viewTouches: viewTouchesForTesting))
            XCTAssertEqual(actionStateManager.currentState, .transformingCanvas, "After resetting, the actionState can be changed.")
        }
    }
}
