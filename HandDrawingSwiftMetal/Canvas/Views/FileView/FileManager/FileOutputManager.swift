//
//  FileOutputManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZipArchive

enum FileOutputManager {

    static func createDirectory(_ directoryUrl: URL) throws {
        do {
            try FileManager.createNewDirectory(url: directoryUrl)
        } catch {
            throw FileOutputError.failedToCreateDirectory
        }
    }

    static func saveTextureAsData(
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
        _ sourceDirectoryURL: URL,
        to destinationZipURL: URL
    ) throws {
        let success = SSZipArchive.createZipFile(
            atPath: destinationZipURL.path,
            withContentsOfDirectory: sourceDirectoryURL.path
        )

        if !success {
            throw FileOutputError.failedToZip
        }
    }

}

enum FileOutputError: Error {
    case failedToZip
    case failedToSaveImage
    case filedToMove
    case failedToUpdateTexture
    case failedToCreateDirectory
}
