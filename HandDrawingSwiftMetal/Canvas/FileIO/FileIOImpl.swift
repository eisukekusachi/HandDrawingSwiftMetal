//
//  FileIOImpl.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import UIKit
import ZipArchive

enum FileOutputError: Error {
    case failedToZip
}
enum FileInputError: Error {
    case failedToUnzip
    case failedToLoadJson
    case failedToApplyData
}

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
    func saveImage(bytes: [UInt8], url: URL) throws {
        try? Data(bytes).write(to: url)
    }
    func saveImage(image: UIImage?, url: URL) throws {
        try? image?.pngData()?.write(to: url)
    }
}
