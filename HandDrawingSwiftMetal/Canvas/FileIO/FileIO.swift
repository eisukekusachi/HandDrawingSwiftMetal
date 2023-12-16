//
//  FileIO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import UIKit

protocol FileIO {
    func zip(_ srcFolderURL: URL, to dstZipURL: URL) throws
    func unzip(_ srcZipURL: URL, to dstFolderURL: URL) throws
    func saveImage(bytes: [UInt8], url: URL) throws
    func saveImage(image: UIImage?, url: URL) throws
}
