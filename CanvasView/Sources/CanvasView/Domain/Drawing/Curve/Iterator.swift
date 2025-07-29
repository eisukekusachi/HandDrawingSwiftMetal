//
//  Iterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

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

    func next(range: Int = 1, _ results: ([Element]) -> Void) {
        if range <= 0 { return }

        while (index + range) <= array.count {
            results(Array(array[index ..< index + range]))
            index += 1
        }
    }
    func next(range: Int) -> [Element]? {
        if range <= 0 { return nil }

        if (index + range) <= array.count {

            let elements = array[index ..< index + range]
            index += 1

            return Array(elements)

        } else {
            return nil
        }
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

    @MainActor
    func reset() {
        index = 0
        array = []
    }

}
