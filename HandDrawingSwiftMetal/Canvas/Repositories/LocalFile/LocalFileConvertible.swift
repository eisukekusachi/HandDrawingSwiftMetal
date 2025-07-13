//
//  LocalFileConvertible.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/12.
//

import Foundation

protocol LocalFileConvertible {
    /// Save this value to a local file at the specified URL
    func write(to url: URL) throws
}
