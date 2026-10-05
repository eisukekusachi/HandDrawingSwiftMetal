//
//  Iterator.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

import Algorithms
import Foundation

class Iterator<T: Equatable>: IteratorProtocol {

    typealias Element = T

    private(set) var array: [Element] = []
    private(set) var index: Int = 0

    var count: Int {
        return array.count
    }
    var currentIndex: Int {
        return index - 1
    }
    var isFirstProcessing: Bool {
        return index == 1
    }

    func next() -> Element? {
        if index < array.count {
            let element = array[index]
            index += 1
            return element
        } else {
            return nil
        }
    }

    /// Overlapping windows that begin at `index`, then advances `index` past them.
    func windows(ofCount count: Int) -> [[Element]] {
        guard count > 0 else { return [] }

        let windows = array.dropFirst(index).windows(ofCount: count).map { Array($0) }
        index += windows.count
        return windows
    }

    func append(_ element: Element) {
        array.append(element)
    }
    func append(_ elements: [Element]) {
        array.append(contentsOf: elements)
    }

    func replace(index: Int, element: Element) {
        array[index] = element
    }

    func reset() {
        index = 0
        array = []
    }
}
