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
}

extension ActionState {
    static let activatingDrawingCount: Int = 5
    static let activatingTransformingCount: Int = 3

    static func isDrawingGesture(_ touchPointsDictionary: [Int: [TouchPoint]]) -> ActionState? {
        if touchPointsDictionary.count != 1 { return nil }

        if let count = touchPointsDictionary.first?.count, count > activatingDrawingCount {
            return .drawing
        }
        return nil
    }
    static func isTransformingGesture(_ touchPointsDictionary: [Int: [TouchPoint]]) -> ActionState? {
        if touchPointsDictionary.count != 2 { return nil }

        if let countA = touchPointsDictionary.first?.count, countA > activatingTransformingCount,
           let countB = touchPointsDictionary.last?.count, countB > activatingTransformingCount {
            return .transforming
        }
        return nil
    }
}