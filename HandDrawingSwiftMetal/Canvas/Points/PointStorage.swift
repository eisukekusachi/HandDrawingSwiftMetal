//
//  PointToCurveConverter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation

protocol PointStorage {
    
    associatedtype Input
    associatedtype StoredPoints
    associatedtype Output
    
    var storedPoints: StoredPoints { get }
    var iterator: Iterator<Output> { get }
    
    func appendPoints(_ value: Input)
    func getIterator(endProcessing: Bool) -> Iterator<Output>
    
    func reset()
}
