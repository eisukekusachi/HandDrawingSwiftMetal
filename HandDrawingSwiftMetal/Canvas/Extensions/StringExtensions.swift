//
//  StringExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/05.
//

import Foundation

extension String {
    var fileName: String {
        if let name = self.components(separatedBy: ".").first {
            return name
        }
        return self
    }
}
