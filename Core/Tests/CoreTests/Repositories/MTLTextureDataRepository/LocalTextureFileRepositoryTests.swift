//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation
import Metal
import Testing
@testable import Core

struct LocalTextureFileRepositoryTests {

    private typealias Subject = LocalTextureFileRepository

    private let textureSize = TestUtils.randomSize()

    @Test
    func `When source layer files are valid, it replaces TextureStorage`() async throws {
        let fileManager = MockFileManager()
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("Source", isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let device = try makeDevice()
        let existingLayerId = UUID()
        let restoredLayerId = UUID()

        let subject = try Subject(
            storageDirectoryURL: rootURL,
            directoryName: "TextureStorage",
            fileManager: fileManager
        )

        try writeLayer(id: restoredLayerId, textureSize: textureSize, in: sourceURL, fileManager: fileManager)
        try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)

        try await subject.restoreStorage(
            from: sourceURL,
            ids: [restoredLayerId],
            textureSize: textureSize,
            device: device
        )

        // Only restoredLayerId is copied into staging; existingLayerId does not remain.
        #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(restoredLayerId.uuidString).path))
        #expect(!fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))

        // Managing the source folder is not this repository's responsibility; it only copies from it. The caller removes the folder when its work is done.
        #expect(fileManager.fileExists(atPath: sourceURL.appendingPathComponent(restoredLayerId.uuidString).path))
        #expect(try childNames(in: rootURL, fileManager: fileManager) == ["Source", "TextureStorage"])
    }

    @Test
    func `When source layer files are missing, it keeps the current TextureStorage`() async throws {
        let fileManager = MockFileManager()
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("Source", isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let device = try makeDevice()
        let existingLayerId = UUID()
        let missingLayerId = UUID()

        let subject = try Subject(
            storageDirectoryURL: rootURL,
            directoryName: "TextureStorage",
            fileManager: fileManager
        )

        try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)
        fileManager.setContentsOfDirectory([], at: sourceURL)

        await #expect(throws: NSError.self) {
            try await subject.restoreStorage(
                from: sourceURL,
                ids: [missingLayerId],
                textureSize: textureSize,
                device: device
            )
        }

        // When restore fails, existing TextureStorage must stay unchanged.
        #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
        #expect(try childNames(in: rootURL, fileManager: fileManager) == ["Source", "TextureStorage"])
    }

    @Test
    func `When a source layer file is empty, it keeps the current TextureStorage`() async throws {
        let fileManager = MockFileManager()
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("Source", isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let device = try makeDevice()
        let existingLayerId = UUID()
        let emptyLayerId = UUID()
        let emptyLayerURL = sourceURL.appendingPathComponent(emptyLayerId.uuidString)

        let subject = try Subject(
            storageDirectoryURL: rootURL,
            directoryName: "TextureStorage",
            fileManager: fileManager
        )

        try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)
        guard fileManager.createFile(atPath: emptyLayerURL.path, contents: Data(), attributes: nil) else {
            Issue.record("Failed to create empty layer file")
            return
        }
        fileManager.setContentsOfDirectory([emptyLayerURL], at: sourceURL)

        await #expect(throws: NSError.self) {
            try await subject.restoreStorage(
                from: sourceURL,
                ids: [emptyLayerId],
                textureSize: textureSize,
                device: device
            )
        }

        // When restore fails, existing TextureStorage must stay unchanged; root must not keep staging or backup directories.
        #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
        #expect(try childNames(in: rootURL, fileManager: fileManager) == ["Source", "TextureStorage"])
    }

    @Test
    func `When copying layer files fails, it keeps the current TextureStorage`() async throws {
        let fileManager = MockFileManager()
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("Source", isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let device = try makeDevice()
        let existingLayerId = UUID()
        let restoredLayerId = UUID()

        let subject = try Subject(
            storageDirectoryURL: rootURL,
            directoryName: "TextureStorage",
            fileManager: fileManager
        )

        try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)
        try writeLayer(id: restoredLayerId, textureSize: textureSize, in: sourceURL, fileManager: fileManager)

        // Copying the same id twice makes the second copyItem fail after staging has started.
        await #expect(throws: NSError.self) {
            try await subject.restoreStorage(
                from: sourceURL,
                ids: [restoredLayerId, restoredLayerId],
                textureSize: textureSize,
                device: device
            )
        }

        // When restore fails, existing TextureStorage must stay unchanged.
        #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
        #expect(try childNames(in: rootURL, fileManager: fileManager) == ["Source", "TextureStorage"])
    }
}

extension LocalTextureFileRepositoryTests {

    private func makeDevice() throws -> MTLDevice {
        try #require(MTLCreateSystemDefaultDevice())
    }

    private func childNames(in directoryURL: URL, fileManager: MockFileManager) throws -> [String] {
        try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .sorted()
    }

    private func writeLayer(
        id: UUID,
        textureSize: CGSize,
        in directoryURL: URL,
        fileManager: MockFileManager
    ) throws {
        let width = Int(textureSize.width)
        let height = Int(textureSize.height)
        let data = Data(repeating: 0, count: width * height * 4)
        let fileURL = directoryURL.appendingPathComponent(id.uuidString)
        guard fileManager.createFile(atPath: fileURL.path, contents: data, attributes: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
