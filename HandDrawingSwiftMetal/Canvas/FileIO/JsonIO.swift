//
//  JsonIO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Foundation

protocol JsonIO {
    func loadJson<T: Codable>(_ url: URL) throws -> T?
    func saveJson<T: Codable>(_ data: T, to jsonURL: URL) throws
}
