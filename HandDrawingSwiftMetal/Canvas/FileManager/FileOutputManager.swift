//
//  FileOutputManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZipArchive

enum FileOutputError: Error {
    case failedToZip
}

enum FileOutputManager {

    static func saveImage(
        bytes: [UInt8],
        to url: URL
    ) throws {
        try Data(bytes).write(to: url)
    }

    static func saveImage(
        image: UIImage?,
        to url: URL
    ) throws {
        try image?.pngData()?.write(to: url)
    }

    static func saveJson<T: Codable>(
        _ data: T,
        to jsonURL: URL
    ) throws {
        let jsonData = try JSONEncoder().encode(data)
        let jsonString = String(data: jsonData, encoding: .utf8)
        try jsonString?.write(
            to: jsonURL,
            atomically: true,
            encoding: .utf8
        )
    }

    static func zip(
        _ sourceFolderURL: URL,
        to destinationZipURL: URL
    ) throws {
        let success = SSZipArchive.createZipFile(
            atPath: destinationZipURL.path,
            withContentsOfDirectory: sourceFolderURL.path
        )

        if !success {
            throw FileOutputError.failedToZip
        }
    }

}
