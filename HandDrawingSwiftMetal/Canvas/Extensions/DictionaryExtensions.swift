//
//  DictionaryExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/01/09.
//

import Foundation

extension Dictionary where Key == Int {
    
    var first: Value? {
        if let key = self.keys.sorted().first {
            return self[key]
        }
        return nil
    }
    var last: Value? {
        if let key = self.keys.sorted().last {
            return self[key]
        }
        return nil
    }
}
