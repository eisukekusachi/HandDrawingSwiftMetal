//
//  ActionStateManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/30.
//

import Foundation

enum ActionState: Int {

    case recognizing
    case drawing
    case transforming

    init(from touchPointsDictionary: [TouchHashValue: [TouchPoint]]) {
        var result: ActionState = .recognizing

        if let actionState = ActionState.isDrawingGesture(touchPointsDictionary) {
            result = actionState

        } else if let actionState = ActionState.isTransformingGesture(touchPointsDictionary) {
            result = actionState
        }

        self = result
    }

}

extension ActionState {

    static let activatingDrawingCount: Int = 6
    static let activatingTransformingCount: Int = 2

    static func isDrawingGesture(_ touchPointsDictionary: [TouchHashValue: [TouchPoint]]) -> ActionState? {
        if touchPointsDictionary.count != 1 { return nil }

        if let count = touchPointsDictionary.first?.count, count > activatingDrawingCount {
            return .drawing
        }
        return nil
    }
    static func isTransformingGesture(_ touchPointsDictionary: [TouchHashValue: [TouchPoint]]) -> ActionState? {
        if touchPointsDictionary.count != 2 { return nil }

        if let countA = touchPointsDictionary.first?.count, countA > activatingTransformingCount,
           let countB = touchPointsDictionary.last?.count, countB > activatingTransformingCount {
            return .transforming
        }
        return nil
    }

}
