//
//  JsonIOImpl.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Foundation

enum JsonError: Error {
    case failedToLoadJson
}

class JsonIOImpl: JsonIO {
    func loadJson<T: Codable>(_ url: URL) throws -> T? {
        guard let stringJson: String = try? String(contentsOf: url, encoding: .utf8),
              let dataJson: Data = stringJson.data(using: .utf8)
        else {
            throw JsonError.failedToLoadJson
        }
        return try JSONDecoder().decode(T.self, from: dataJson)
    }
    func saveJson<T: Codable>(_ data: T, to jsonURL: URL) throws {
        if let jsonData = try? JSONEncoder().encode(data) {
            try String(data: jsonData, encoding: .utf8)?.write(to: jsonURL, atomically: true, encoding: .utf8)
        }
    }
}
