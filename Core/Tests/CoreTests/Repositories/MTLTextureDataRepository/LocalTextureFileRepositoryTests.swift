//
//  Created by Eisuke Kusachi
//

import CoreGraphics
import Foundation
import Testing
@testable import Core

struct LocalTextureFileRepositoryTests {

    struct RestoreStorage {

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
                textureSize: textureSize
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
                    textureSize: textureSize
                )
            }

            // When restore fails, existing TextureStorage must stay unchanged.
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
                    textureSize: textureSize
                )
            }

            // When restore fails, existing TextureStorage must stay unchanged.
            #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
            #expect(try childNames(in: rootURL, fileManager: fileManager) == ["Source", "TextureStorage"])
        }

        @Test
        func `When a source layer file has the wrong byte count, it keeps the current TextureStorage`() async throws {
            let fileManager = MockFileManager()
            let rootURL = fileManager.temporaryDirectory
                .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
            let sourceURL = rootURL.appendingPathComponent("Source", isDirectory: true)
            let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: rootURL) }

            let existingLayerId = UUID()
            let invalidLayerId = UUID()
            let invalidLayerURL = sourceURL.appendingPathComponent(invalidLayerId.uuidString)

            let subject = try Subject(
                storageDirectoryURL: rootURL,
                directoryName: "TextureStorage",
                fileManager: fileManager
            )

            try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)
            try writeLayer(id: invalidLayerId, byteCount: 4, in: sourceURL, fileManager: fileManager)
            fileManager.setContentsOfDirectory([invalidLayerURL], at: sourceURL)

            await #expect(throws: NSError.self) {
                try await subject.restoreStorage(
                    from: sourceURL,
                    ids: [invalidLayerId],
                    textureSize: textureSize
                )
            }

            #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
            #expect(try childNames(in: rootURL, fileManager: fileManager) == ["Source", "TextureStorage"])
        }
    }

    struct ValidateTextureFilesInLocalDirectory {

        private typealias Subject = LocalTextureFileRepository

        private let textureSize = TestUtils.randomSize()

        @Test
        func `When local layer files are missing, it throws`() throws {
            let fileManager = MockFileManager()
            let rootURL = fileManager.temporaryDirectory
                .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
            let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: rootURL) }

            let existingLayerId = UUID()
            let missingLayerId = UUID()
            let subject = try Subject(
                storageDirectoryURL: rootURL,
                directoryName: "TextureStorage",
                fileManager: fileManager
            )
            try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)

            #expect(throws: NSError.self) {
                try subject.validateTextureFilesInLocalDirectory(
                    ids: [missingLayerId],
                    textureSize: textureSize
                )
            }

            // Validation must not create, move, or delete files.
            #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
            #expect(try childNames(in: rootURL, fileManager: fileManager) == ["TextureStorage"])
        }

        @Test
        func `When a local layer file has the wrong byte count, it throws`() throws {
            let fileManager = MockFileManager()
            let rootURL = fileManager.temporaryDirectory
                .appendingPathComponent("LocalTextureFileRepositoryTests-\(UUID().uuidString)", isDirectory: true)
            let storageURL = rootURL.appendingPathComponent("TextureStorage", isDirectory: true)
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: rootURL) }

            let existingLayerId = UUID()
            let invalidLayerId = UUID()
            let invalidLayerURL = storageURL.appendingPathComponent(invalidLayerId.uuidString)
            let subject = try Subject(
                storageDirectoryURL: rootURL,
                directoryName: "TextureStorage",
                fileManager: fileManager
            )
            try writeLayer(id: existingLayerId, textureSize: textureSize, in: storageURL, fileManager: fileManager)
            try writeLayer(id: invalidLayerId, byteCount: 4, in: storageURL, fileManager: fileManager)

            #expect(throws: NSError.self) {
                try subject.validateTextureFilesInLocalDirectory(
                    ids: [invalidLayerId],
                    textureSize: textureSize
                )
            }

            // Validation must not create, move, or delete files.
            #expect(fileManager.fileExists(atPath: storageURL.appendingPathComponent(existingLayerId.uuidString).path))
            #expect(fileManager.fileExists(atPath: invalidLayerURL.path))
            #expect(try childNames(in: rootURL, fileManager: fileManager) == ["TextureStorage"])
        }
    }
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
    try writeLayer(
        id: id,
        byteCount: width * height * 4,
        in: directoryURL,
        fileManager: fileManager
    )
}

private func writeLayer(
    id: UUID,
    byteCount: Int,
    in directoryURL: URL,
    fileManager: MockFileManager
) throws {
    let fileURL = directoryURL.appendingPathComponent(id.uuidString)
    guard fileManager.createFile(
        atPath: fileURL.path,
        contents: Data(repeating: 0, count: byteCount),
        attributes: nil
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
}
