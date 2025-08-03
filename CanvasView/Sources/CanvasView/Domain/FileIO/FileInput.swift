//
//  FileInput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZIPFoundation

enum FileInput {

    static func loadTexture(url: URL, textureSize: CGSize, device: MTLDevice) throws -> MTLTexture? {
        guard
            let hexadecimalData = try Data(contentsOf: url).encodedHexadecimals
        else { return nil }
        return MTLTextureCreator.makeTexture(
            size: textureSize,
            colorArray: hexadecimalData,
            with: device
        )
    }

    static func loadJson<T: Codable>(_ url: URL) throws -> T? {
        let jsonString: String = try String(contentsOf: url, encoding: .utf8)
        guard let dataJson = jsonString.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(T.self, from: dataJson)
    }

    static func unzip(sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
    }
}
