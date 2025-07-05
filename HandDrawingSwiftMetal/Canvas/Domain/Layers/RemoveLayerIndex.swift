//
//  RemoveLayerIndex.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/03.
//

import Foundation

enum RemoveLayerIndex {

    static func selectedIndexAfterDeletion(selectedIndex: Int) -> Int {
        max(selectedIndex - 1, 0)
    }

}
