//
//  TextureLayerUndoAction.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

enum TextureLayerUndoAction {
    case drawing(index: Int)
    case insert(index: Int)
    case remove(index: Int)
    case move(fromIndex: Int, toIndex: Int)
    case edit(index: Int)

    func isEqual(_ type: TextureLayerUndoAction) -> Bool {
        switch (self, type) {
        case let (.drawing(index0), .drawing(index1)):
            index0 == index1
        case let (.insert(index0), .insert(index1)):
            index0 == index1
        case let (.remove(index0), .remove(index1)):
            index0 == index1
        case let (.move(fromIndex0, toIndex0), .move(fromIndex1, toIndex1)):
            fromIndex0 == fromIndex1 && toIndex0 == toIndex1
        case let (.edit(index0), .edit(index1)):
            index0 == index1
        default: false
        }
    }

}
