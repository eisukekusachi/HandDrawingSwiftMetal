//
//  ArrayExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import Foundation

extension Array where Element: Equatable {

    /// Retrieves all elements starting from the element after the specified element.
    /// - Parameter element: The element to start after
    /// - Returns: A subarray starting from the element after the specified element, or `nil` if the element is not found.
    func elements(after element: Element?) -> [Element]? {
        guard
            let element,
            let index = self.lastIndex(of: element)
        else { return nil }

        // Ensure index + 1 does not exceed the array bounds
        guard (index + 1) < self.count else { return [] }

        return Array(self.suffix(from: index + 1))
    }

}
