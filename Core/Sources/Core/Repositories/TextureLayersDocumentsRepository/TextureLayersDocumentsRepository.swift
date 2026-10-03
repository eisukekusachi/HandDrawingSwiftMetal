//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation

@preconcurrency import MetalKit

private struct TextureSource: Sendable {
    let id: UUID
    let width: Int
    let height: Int
    let hexadecimalData: [UInt8]
}

/// Manages and persists texture bytes on disk, keyed by id.
public final class TextureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol {
    @MainActor
    public static let shared: any TextureLayersDocumentsRepositoryProtocol = {
        do {
            return try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage"
            )
        } catch {
            fatalError("Failed to initialize TextureLayersDocumentsRepository: \(error)")
        }
    }()

    /// URL of the texture storage
    public let workingDirectoryURL: URL

    private init(
        storageDirectoryURL: URL,
        directoryName: String
    ) throws {
        self.workingDirectoryURL = storageDirectoryURL.appendingPathComponent(directoryName)

        try FileManager.createDirectory(workingDirectoryURL)

        // Do not back up because this is an intermediate directory
        var url = workingDirectoryURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
    }

    public func initializeStorage(
        id: UUID,
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        guard
            Int(textureSize.width) >= TextureBytes.minimumLength && Int(textureSize.height) >= TextureBytes.minimumLength,
            let newTexture = TextureBytes.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        removeAll()

        let textureData = try await newTexture.data(
            device: device,
            commandQueue: commandQueue
        )
        try await addTextureData(
            data: textureData,
            id: id
        )
    }

    public func restoreStorageFromWorkingDirectory(
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws {
        try loadTexturesIfValid(
            from: workingDirectoryURL,
            ids: ids,
            textureSize: textureSize,
            device: device
        )
    }

    public func restoreStorage(
        from sourceFolderURL: URL,
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> Bool {
        try loadTexturesIfValid(
            from: sourceFolderURL,
            ids: ids,
            textureSize: textureSize,
            device: device
        )

        removeAll()

        try ids.forEach { id in
            try FileManager.default.moveItem(
                at: sourceFolderURL.appendingPathComponent(id.uuidString),
                to: workingDirectoryURL.appendingPathComponent(id.uuidString)
            )
        }

        return true
    }
}

public extension TextureLayersDocumentsRepository {

    @discardableResult
    func addTextureData(
        data: Data,
        id: UUID
    ) async throws -> Bool {
        guard
            !FileManager.default.fileExists(atPath: workingDirectoryURL.appendingPathComponent(id.uuidString).path)
        else {
            Logger.info("File already exists")
            return false
        }

        try await writeDataToDisk(
            id: id,
            data: data
        )

        return true
    }

    func duplicatedTexture(
        _ id: UUID,
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> MTLTexture {
        guard
            Int(textureSize.width) >= TextureBytes.minimumLength &&
            Int(textureSize.height) >= TextureBytes.minimumLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        let destinationUrl = workingDirectoryURL.appendingPathComponent(id.uuidString)

        guard
            let newTexture: MTLTexture = try TextureBytes.makeTexture(
                url: destinationUrl,
                size: textureSize,
                with: device
            )
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "File not found: \(destinationUrl.path)"
                )
            )
            Logger.error(error)
            throw error
        }

        return newTexture
    }

    func duplicatedTextures(
        _ ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) async throws -> [(UUID, MTLTexture)] {
        guard
            Int(textureSize.width) >= TextureBytes.minimumLength,
            Int(textureSize.height) >= TextureBytes.minimumLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        let width = Int(textureSize.width)
        let height = Int(textureSize.height)
        let sources: [TextureSource] = try await withThrowingTaskGroup(of: TextureSource.self) { group in
            for id in ids {
                let url = workingDirectoryURL.appendingPathComponent(id.uuidString)

                group.addTask {
                    guard let hexadecimalData = try TextureBytes.loadHexadecimalData(from: url) else {
                        let error = NSError(
                            title: String(localized: "Error"),
                            message: String(localized: "File not found: \(url.path)")
                        )
                        Logger.error(error)
                        throw error
                    }
                    return TextureSource(
                        id: id,
                        width: width,
                        height: height,
                        hexadecimalData: hexadecimalData
                    )
                }
            }

            var results: [TextureSource] = []
            results.reserveCapacity(ids.count)

            for try await result in group {
                results.append(result)
            }

            return results
        }

        var textures: [(UUID, MTLTexture)] = []
        textures.reserveCapacity(sources.count)

        for source in sources {
            let texture = try TextureBytes.makeTexture(
                width: source.width,
                height: source.height,
                from: source.hexadecimalData,
                with: device
            )
            textures.append((source.id, texture))
        }

        return textures
    }

    func removeAll() {
        do {
            try FileManager.createNewDirectory(workingDirectoryURL)
        } catch {
            Logger.error(error)
        }
    }

    @discardableResult
    func removeTexture(_ id: UUID) throws -> Bool {
        let fileURL = workingDirectoryURL.appendingPathComponent(id.uuidString)

        guard
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            Logger.info("Unable to find \(id.uuidString)")
            return false
        }
        try FileManager.default.removeItem(at: fileURL)

        return true
    }

    @discardableResult
    func copyTexture(
        id: UUID,
        to destinationURL: URL
    ) async throws -> Bool {
        let sourceURL = workingDirectoryURL.appendingPathComponent(id.uuidString)
        let destinationFileURL = destinationURL.appendingPathComponent(id.uuidString)

        guard
            FileManager.default.fileExists(atPath: sourceURL.path)
        else {
            Logger.info("Unable to find \(id.uuidString)")
            return false
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationFileURL)

        return true
    }

    func writeDataToDisk(
        id: UUID,
        data: Data
    ) async throws {
        let url = workingDirectoryURL.appendingPathComponent(id.uuidString)

        try await Task.detached(priority: .utility) { [data, url] in
            try data.write(to: url, options: .atomic)
        }.value
    }
}

private extension TextureLayersDocumentsRepository {

    func loadTexturesIfValid(
        from directoryURL: URL,
        ids: [UUID],
        textureSize: CGSize,
        device: MTLDevice
    ) throws {
        guard FileManager.containsAllFileNames(
            fileNames: ids.map(\.uuidString),
            in: FileManager.contentsOfDirectory(directoryURL)
        ) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to find texture layer files")
            )
            Logger.error(error)
            throw error
        }

        try ids.forEach { id in
            let textureData = try Data(
                contentsOf: directoryURL.appendingPathComponent(id.uuidString)
            )

            guard !textureData.isEmpty else {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Unable to load required data")
                )
                Logger.error(error)
                throw error
            }

            let _ = try TextureBytes.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                from: [UInt8](textureData),
                with: device
            )
        }
    }
}

private enum TextureBytes {
    static let minimumLength = 16

    static func loadHexadecimalData(
        from url: URL
    ) throws -> [UInt8]? {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return nil }
        return [UInt8](data)
    }

    static func makeTexture(
        url: URL,
        size: CGSize,
        with device: MTLDevice
    ) throws -> MTLTexture? {
        guard
            let hexadecimalData = try loadHexadecimalData(from: url)
        else { return nil }
        return try makeTexture(
            width: Int(size.width),
            height: Int(size.height),
            from: hexadecimalData,
            with: device
        )
    }

    static func makeTexture(
        width: Int,
        height: Int,
        with device: MTLDevice
    ) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [
            .renderTarget,
            .shaderRead,
            .shaderWrite
        ]
        return device.makeTexture(descriptor: textureDescriptor)
    }

    static func makeTexture(
        width: Int,
        height: Int,
        from colorArray: [UInt8],
        with device: MTLDevice
    ) throws -> MTLTexture {
        let bytesPerPixel = 4

        guard colorArray.count == width * height * bytesPerPixel else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid value")
            )
            Logger.error(error)
            throw error
        }

        let bytesPerRow = bytesPerPixel * width

        guard let texture = makeTexture(
            width: width,
            height: height,
            with: device
        ) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create texture")
            )
            Logger.error(error)
            throw error
        }

        colorArray.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                slice: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerRow * height
            )
        }

        return texture
    }
}
