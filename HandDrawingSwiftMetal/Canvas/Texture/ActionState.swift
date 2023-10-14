//
//  ActionStateManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/30.
//

import Foundation

enum ActionState: Int {
    
    case recognizing
    case drawingOnCanvas
    case transformingCanvas
    
    static let activatingDrawingCount: Int = 5
    static let activatingTransformingCount: Int = 3
    
    static func getCurrentState(viewTouches: [Int: [TouchPoint]]) -> ActionState {
        var result: ActionState = .recognizing
    
        if result == .recognizing, let actionState = ActionState.isDrawingGestureOrNot(viewTouches: viewTouches) {
            result = actionState
        }
        
        if result == .recognizing, let actionState = ActionState.isTransformingGestureOrNot(viewTouches: viewTouches) {
            result = actionState
        }
    
        return result
    }
    
    static func isDrawingGestureOrNot(viewTouches: [Int: [TouchPoint]]) -> ActionState? {
        if viewTouches.count != 1 { return nil }
        
        if let count = viewTouches.first?.count, count > activatingDrawingCount {
            return .drawingOnCanvas
        }
        return nil
    }
    static func isTransformingGestureOrNot(viewTouches: [Int: [TouchPoint]]) -> ActionState? {
        if viewTouches.count != 2 { return nil }
        
        if let countA = viewTouches.first?.count, countA > activatingTransformingCount,
           let countB = viewTouches.last?.count, countB > activatingTransformingCount {
            return .transformingCanvas
        }
        return nil
    }
}
