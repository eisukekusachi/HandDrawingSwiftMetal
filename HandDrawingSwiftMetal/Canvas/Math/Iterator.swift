//
//  Iterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/03.
//

import Foundation

class Iterator<T>: IteratorProtocol {
    
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
            let elem = array[index]
            index += 1
            return elem
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
            
            let elems = array[index ..< index + range]
            index += 1
            
            return Array(elems)
            
        } else {
            return nil
        }
    }
    func append(elem: Element) {
        array.append(elem)
    }
    func append(elems: [Element]) {
        array.append(contentsOf: elems)
    }
    
    func update(elems: [Element]) {
        let elems = getDifference(array: elems, count: array.count)
        
        if elems.count != 0 {
            append(elems: elems)
        }
    }
    func clear() {
        index = 0
        array = []
    }
    
    private func getDifference(array: [T], count: Int) -> [T] {
        if count < array.count {
            return Array(array[count ..< array.count])
        }
        return []
    }
}
