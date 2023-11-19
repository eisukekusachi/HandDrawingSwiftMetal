//
//  TouchPointStorageProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation

protocol TouchPointStorageProtocol {
    var iterator: Iterator<TouchPoint> { get }

    func getIterator(endProcessing: Bool) -> Iterator<TouchPoint>
    func clear()
}
