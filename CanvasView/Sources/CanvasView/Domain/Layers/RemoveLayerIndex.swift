//
//  RemoveLayerIndex.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/03.
//

import Foundation

public enum RemoveLayerIndex {

    // After deleting the layer at the specified index:
    // if the index is 0, the next index becomes 1;
    // otherwise, the next index is (index - 1).
    public static func nextLayerIndexAfterDeletion(index: Int) -> Int {
        index == 0 ? 1 : index - 1
    }
}
