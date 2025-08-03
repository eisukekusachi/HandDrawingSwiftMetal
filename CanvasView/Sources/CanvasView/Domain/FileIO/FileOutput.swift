//
//  FileOutput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZIPFoundation

enum FileOutput {

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

    static func zip(sourceURLs: [URL], to zipFileURL: URL) throws {
        let archive = try Archive(url: zipFileURL, accessMode: .create)
        try sourceURLs.forEach { url in
            try archive.addEntry(
                with: url.lastPathComponent,
                fileURL: url,
                compressionMethod: .deflate
            )
        }
    }
}
