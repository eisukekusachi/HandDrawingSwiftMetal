//
//  Iterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

import Foundation

public class Iterator<T: Equatable>: IteratorProtocol {

    public typealias Element = T

    private(set) var array: [Element] = []
    private(set) var index: Int = 0

    public var count: Int {
        return array.count
    }
    public var currentIndex: Int {
        return index - 1
    }
    public var isFirstProcessing: Bool {
        return index == 1
    }

    public func next() -> Element? {
        if index < array.count {
            let element = array[index]
            index += 1
            return element
        } else {
            return nil
        }
    }

    public func next(range: Int = 1, _ results: ([Element]) -> Void) {
        if range <= 0 { return }

        while (index + range) <= array.count {
            results(Array(array[index ..< index + range]))
            index += 1
        }
    }
    public func next(range: Int) -> [Element]? {
        if range <= 0 { return nil }

        if (index + range) <= array.count {

            let elements = array[index ..< index + range]
            index += 1

            return Array(elements)

        } else {
            return nil
        }
    }
    public func append(_ element: Element) {
        array.append(element)
    }
    public func append(_ elements: [Element]) {
        array.append(contentsOf: elements)
    }

    public func replace(index: Int, element: Element) {
        array[index] = element
    }

    @MainActor
    public func reset() {
        index = 0
        array = []
    }
}
