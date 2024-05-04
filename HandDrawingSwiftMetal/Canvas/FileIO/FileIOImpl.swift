//
//  FileIOImpl.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import UIKit
import ZipArchive

class FileIOImpl: FileIO {
    func zip(_ srcFolderURL: URL, to dstZipURL: URL) throws {
        let success = SSZipArchive.createZipFile(atPath: dstZipURL.path,
                                                 withContentsOfDirectory: srcFolderURL.path)
        if !success {
            throw FileOutputError.failedToZip
        }
    }
    func unzip(_ srcZipURL: URL, to dstFolderURL: URL) throws {
        if !SSZipArchive.unzipFile(atPath: srcZipURL.path, toDestination: dstFolderURL.path) {
            throw FileInputError.failedToUnzip
        }
    }
    func loadJson<T: Codable>(_ url: URL) throws -> T? {
        guard let stringJson: String = try? String(contentsOf: url, encoding: .utf8),
              let dataJson: Data = stringJson.data(using: .utf8)
        else {
            throw FileInputError.failedToLoadJson
        }
        return try JSONDecoder().decode(T.self, from: dataJson)
    }
    func saveJson<T: Codable>(_ data: T, to jsonURL: URL) throws {
        if let jsonData = try? JSONEncoder().encode(data) {
            try String(data: jsonData, encoding: .utf8)?.write(to: jsonURL, atomically: true, encoding: .utf8)
        }
    }
}
