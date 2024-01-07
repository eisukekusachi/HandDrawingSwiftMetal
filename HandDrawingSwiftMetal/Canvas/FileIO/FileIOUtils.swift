//
//  FileIOUtils.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/06.
//

import UIKit

enum FileIOUtils {
    static func saveImage(bytes: [UInt8], to url: URL) throws {
        try? Data(bytes).write(to: url)
    }
    static func saveImage(image: UIImage?, to url: URL) throws {
        try? image?.pngData()?.write(to: url)
    }
}
