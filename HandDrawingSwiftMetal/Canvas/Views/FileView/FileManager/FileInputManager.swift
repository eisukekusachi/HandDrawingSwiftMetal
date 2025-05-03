//
//  FileInputManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZipArchive

enum FileInputManager {
    @Sendable
    static func getCanvasEntity(fileURL: URL) throws -> CanvasEntity {
        if let jsonData: CanvasEntity = try FileInputManager.loadJson(fileURL) {
            return jsonData

        } else if let jsonData: OldCanvasEntity = try FileInputManager.loadJson(fileURL) {
            return CanvasEntity.init(entity: jsonData)
        }

        throw FileInputError.cannotFindFile
    }

    static func loadTexture(_ fileUrl: URL, textureSize: CGSize, device: MTLDevice) throws -> MTLTexture? {
        let textureData = try Data(contentsOf: fileUrl)
        guard
            let hexadecimalData = textureData.encodedHexadecimals
        else { return nil }

        return MTLTextureCreator.makeTexture(
            size: textureSize,
            colorArray: hexadecimalData,
            with: device
        )
    }

    static func loadJson<T: Codable>(_ url: URL) throws -> T? {
        let jsonString: String = try String(contentsOf: url, encoding: .utf8)
        let dataJson: Data? = jsonString.data(using: .utf8)

        guard let dataJson else {
            throw FileInputError.failedToConvertData
        }

        return try JSONDecoder().decode(T.self, from: dataJson)
    }

    static func unzip(_ sourceZipURL: URL, to destinationFolderURL: URL) async throws {
        if !SSZipArchive.unzipFile(
            atPath: sourceZipURL.path,
            toDestination: destinationFolderURL.path
        ) {
            throw FileInputError.failedToUnzip
        }
    }

}

enum FileInputError: Error {
    case cannotFindFile
    case failedToUnzip
    case failedToConvertData
    case failedToLoadJson
    case failedToApplyData
}
