//
//  InputData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZipArchive

enum InputData {
    @Sendable
    static func getCanvasEntity(fileURL: URL) throws -> CanvasEntity {
        if let jsonData: CanvasEntity = try InputData.loadJson(fileURL) {
            return jsonData

        } else if let jsonData: OldCanvasEntity = try InputData.loadJson(fileURL) {
            return CanvasEntity.init(entity: jsonData)
        }

        throw InputDataError.cannotFindFile
    }

    static func loadTexture(url: URL, textureSize: CGSize, device: MTLDevice) throws -> MTLTexture? {
        let textureData = try Data(contentsOf: url)
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
            throw InputDataError.failedToConvertData
        }

        return try JSONDecoder().decode(T.self, from: dataJson)
    }

    static func unzip(_ sourceZipURL: URL, to destinationFolderURL: URL) async throws {
        if !SSZipArchive.unzipFile(
            atPath: sourceZipURL.path,
            toDestination: destinationFolderURL.path
        ) {
            throw InputDataError.failedToUnzip
        }
    }

    /// Checks whether the contents of the specified directory exactly match the given set of file names
    static func containsAllFiles(
        at directory: URL,
        fileNames: [String]
    ) -> Bool {
        let fileURLs: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let expectedNames = Set(fileNames)
        return !expectedNames.isEmpty && Set(fileURLs.map { $0.lastPathComponent }) == expectedNames
    }
}

enum InputDataError: Error {
    case cannotFindFile
    case failedToUnzip
    case failedToConvertData
}
