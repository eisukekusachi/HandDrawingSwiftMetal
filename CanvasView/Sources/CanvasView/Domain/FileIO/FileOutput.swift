//
//  FileOutput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit
import ZIPFoundation

enum FileOutput {

    static func saveTexture(
        from texture: MTLTexture,
        with device: MTLDevice?,
        to url: URL
    ) async throws {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height

        guard
            let device,
            let buffer = device.makeBuffer(length: dataSize, options: [.storageModeShared]),
            let commandQueue = device.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Unable to load required data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        commandEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: dataSize
        )
        commandEncoder.endEncoding()

        try await commandBuffer.commitAndWaitAsync()

        let rawPointer = buffer.contents()
        let data = Data(bytes: rawPointer, count: dataSize)
        try data.write(to: url, options: .atomic)
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
