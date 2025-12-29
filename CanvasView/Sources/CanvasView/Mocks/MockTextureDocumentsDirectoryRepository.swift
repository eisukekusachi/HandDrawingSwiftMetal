//
//  MockTextureDocumentsDirectoryRepository.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/29.
//

import Foundation
@preconcurrency import MetalKit

@MainActor
public final class MockTextureDocumentsDirectoryRepository: TextureDocumentsDirectoryRepositoryProtocol {

    // MARK: - Stored State

    public private(set) var textureSize: CGSize = .zero
    public let directoryName: String
    public let workingDirectoryURL: URL

    /// In-memory textures keyed by LayerId (acts like "disk" for tests)
    public private(set) var storedTextures: [LayerId: MTLTexture] = [:]

    // MARK: - Call Recording

    public private(set) var initializeStorage_textureLayersState_callCount = 0
    public private(set) var initializeStorage_textureLayersState_lastArg: TextureLayersState?

    public private(set) var initializeStorage_newTextureSize_callCount = 0
    public private(set) var initializeStorage_newTextureSize_lastArg: CGSize?

    public private(set) var restoreStorage_callCount = 0
    public private(set) var restoreStorage_lastSourceURL: URL?
    public private(set) var restoreStorage_lastState: TextureLayersState?

    public private(set) var duplicatedTexture_callCount = 0
    public private(set) var duplicatedTexture_lastId: LayerId?

    public private(set) var duplicatedTextures_callCount = 0
    public private(set) var duplicatedTextures_lastIds: [LayerId]?

    public private(set) var removeAll_callCount = 0

    public private(set) var removeTexture_callCount = 0
    public private(set) var removeTexture_lastId: LayerId?

    public private(set) var addTexture_callCount = 0
    public private(set) var addTexture_lastId: LayerId?
    public private(set) var addTexture_lastTexture: MTLTexture?

    public private(set) var writeTextureToDisk_callCount = 0
    public private(set) var writeTextureToDisk_lastId: LayerId?
    public private(set) var writeTextureToDisk_lastTexture: MTLTexture?

    // MARK: - Error Injection / Stubbing

    public var initializeStorage_textureLayersState_error: Error?
    public var initializeStorage_newTextureSize_error: Error?
    public var restoreStorage_error: Error?
    public var duplicatedTexture_error: Error?
    public var duplicatedTextures_error: Error?
    public var removeTexture_error: Error?
    public var addTexture_error: Error?
    public var writeTextureToDisk_error: Error?

    /// If set, this result is returned from `initializeStorage(newTextureSize:)`.
    /// If nil, the mock returns a simple default state (1 layer) without creating textures.
    public var initializeStorage_newTextureSize_result: TextureLayersState?

    /// If set, this mapping is used to return a specific IdentifiedTexture for `duplicatedTexture`.
    public var duplicatedTexture_stubbedResults: [LayerId: IdentifiedTexture] = [:]

    // MARK: - Init

    public init(
        directoryName: String = "MockTextures",
        workingDirectoryURL: URL = URL(fileURLWithPath: "/tmp/MockTextures")
    ) {
        self.directoryName = directoryName
        self.workingDirectoryURL = workingDirectoryURL
    }

    // MARK: - API

    public func restoreStorageFromCoreData(textureLayersState: TextureLayersState) throws {
        initializeStorage_textureLayersState_callCount += 1
        initializeStorage_textureLayersState_lastArg = textureLayersState

        if let error = initializeStorage_textureLayersState_error { throw error }

        // Simulate "retaining" size (like the real repo)
        self.textureSize = textureLayersState.textureSize
    }

    public func initializeStorage(
        newTextureLayersState: TextureLayersState
    ) async throws {
        initializeStorage_newTextureSize_callCount += 1
        initializeStorage_newTextureSize_lastArg = newTextureLayersState.textureSize

        self.textureSize = newTextureLayersState.textureSize
    }

    public func restoreStorageFromSavedData(url sourceFolderURL: URL, textureLayersState: TextureLayersState) async throws {
        restoreStorage_callCount += 1
        restoreStorage_lastSourceURL = sourceFolderURL
        restoreStorage_lastState = textureLayersState

        if let error = restoreStorage_error { throw error }

        // Simulate restoring size; texture contents are not loaded in this mock.
        self.textureSize = textureLayersState.textureSize
    }

    public func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture {
        duplicatedTexture_callCount += 1
        duplicatedTexture_lastId = id

        if let error = duplicatedTexture_error { throw error }

        if let stub = duplicatedTexture_stubbedResults[id] {
            return stub
        }

        guard let texture = storedTextures[id] else {
            struct NotFound: Error {}
            throw NotFound()
        }

        // NOTE: This does not duplicate GPU memory; it returns the stored reference.
        // For unit tests focused on flow/logic, this is usually sufficient.
        return .init(id: id, texture: texture)
    }

    public func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture] {
        duplicatedTextures_callCount += 1
        duplicatedTextures_lastIds = ids

        if let error = duplicatedTextures_error { throw error }

        var results: [IdentifiedTexture] = []
        results.reserveCapacity(ids.count)
        for id in ids {
            results.append(try await duplicatedTexture(id))
        }
        return results
    }

    public func removeAll() {
        removeAll_callCount += 1
        storedTextures.removeAll()
        textureSize = .zero
    }

    public func removeTexture(_ id: LayerId) throws {
        removeTexture_callCount += 1
        removeTexture_lastId = id

        if let error = removeTexture_error { throw error }

        storedTextures.removeValue(forKey: id)
    }

    public func addTexture(texture: MTLTexture, id: LayerId) async throws {
        addTexture_callCount += 1
        addTexture_lastId = id
        addTexture_lastTexture = texture

        if let error = addTexture_error { throw error }

        storedTextures[id] = texture
    }

    public func writeTextureToDisk(texture: MTLTexture, for id: LayerId) async throws {
        writeTextureToDisk_callCount += 1
        writeTextureToDisk_lastId = id
        writeTextureToDisk_lastTexture = texture

        if let error = writeTextureToDisk_error { throw error }

        // "Update" behavior
        storedTextures[id] = texture
    }
}
