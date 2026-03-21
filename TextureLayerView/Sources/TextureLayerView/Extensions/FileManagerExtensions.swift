//
//  FileManagerExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import Foundation

@preconcurrency import MetalKit

public extension FileManager {

    static func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func createNewDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(atPath: url.path)
        }

        try FileManager.createDirectory(url)
    }

    /// The URL of a canvas file stored in the Documents directory
    static func documentsFileURL(projectName: String, suffix: String) -> URL {
        URL.documents.appendingPathComponent(projectName + "." + suffix)
    }

    static func contentsOfDirectory(_ url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }

    /// Checks whether all specified file names are present in the given list of URLs
    static func containsAllFileNames(fileNames: [String], in fileURLs: [URL]) -> Bool {
        guard !fileNames.isEmpty else { return false }
        return Set(fileNames).isSubset(of: Set(fileURLs.map { $0.lastPathComponent }))
    }

    static func saveTexture(
        fileName: String,
        texture: MTLTexture,
        in directory: URL,
        device: MTLDevice?
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
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
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

        try data.write(
            to: directory.appendingPathComponent(fileName),
            options: .atomic
        )
    }
}
