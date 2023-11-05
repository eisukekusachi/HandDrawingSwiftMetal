//
//  FileOutput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import Foundation
import ZipArchive

enum FileOutputError: Error {
    case failedToZip
}

enum FileOutput {
    static func zip(folderURL: URL, zipFileURL: URL) throws {
        let success = SSZipArchive.createZipFile(atPath: zipFileURL.path,
                                                  withContentsOfDirectory: folderURL.path)
        if !success {
            throw FileOutputError.failedToZip
        }
    }
}
