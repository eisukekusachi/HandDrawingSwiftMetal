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
}

extension ActionState {
    static let activatingDrawingCount: Int = 5
    static let activatingTransformingCount: Int = 3

    static func isDrawingGesture(touchPoints: [Int: [TouchPoint]]) -> ActionState? {
        if touchPoints.count != 1 { return nil }

        if let count = touchPoints.first?.count, count > activatingDrawingCount {
            return .drawingOnCanvas
        }
        return nil
    }
    static func isTransformingGesture(touchPoints: [Int: [TouchPoint]]) -> ActionState? {
        if touchPoints.count != 2 { return nil }

        if let countA = touchPoints.first?.count, countA > activatingTransformingCount,
           let countB = touchPoints.last?.count, countB > activatingTransformingCount {
            return .transformingCanvas
        }
        return nil
    }
}
