//
//  FileIO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import UIKit

/// A protocol for managing file input and output
protocol FileIO {
    func zip(_ srcFolderURL: URL, to dstZipURL: URL) throws
    func unzip(_ srcZipURL: URL, to dstFolderURL: URL) throws
    func saveImage(bytes: [UInt8], to url: URL) throws
    func saveImage(image: UIImage?, to url: URL) throws

    func loadJson<T: Codable>(_ url: URL) throws -> T?
    func saveJson<T: Codable>(_ data: T, to jsonURL: URL) throws
}
