//
//  CollectionExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

extension Collection where Index == Int {

    func safeSlice(lower: Int, upper: Int) -> SubSequence {
        guard
            lower <= upper,
            indices.contains(lower),
            indices.contains(upper)
        else {
            return self[startIndex ..< startIndex]
        }

        return self[lower ... upper]
    }

}
