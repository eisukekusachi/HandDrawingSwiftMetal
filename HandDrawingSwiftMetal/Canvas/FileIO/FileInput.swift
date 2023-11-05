//
//  FileInput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/05.
//


import Foundation
import ZipArchive

enum InputError: Error {
    case failedToUnzipFile
    case failedToLoadJson
}

enum FileInput {
    static func unzip(srcZipURL: URL, to dstFolderURL: URL) throws {
        if !SSZipArchive.unzipFile(atPath: srcZipURL.path, toDestination: dstFolderURL.path) {
            throw InputError.failedToUnzipFile
        }
    }

    static func loadJson<T: Decodable>(url: URL) throws -> T {
        guard let stringJson: String = try? String(contentsOf: url, encoding: .utf8),
              let dataJson: Data = stringJson.data(using: .utf8)
        else {
            throw InputError.failedToLoadJson
        }

        return try JSONDecoder().decode(T.self, from: dataJson)
    }
}
