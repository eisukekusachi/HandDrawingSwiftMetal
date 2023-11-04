//
//  URLExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension URL {
    static var documents: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
    }
    static var tmp: URL {
        URL(fileURLWithPath: NSHomeDirectory() + NSHomeDirectory() + "/Documents/tmp")
    }
    static var workInProgress: URL {
        URL(fileURLWithPath: NSHomeDirectory() + NSHomeDirectory() + "/Documents/workinprogress")
    }
}
