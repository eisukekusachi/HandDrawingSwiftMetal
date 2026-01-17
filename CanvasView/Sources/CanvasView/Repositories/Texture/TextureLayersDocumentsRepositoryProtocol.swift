//
//  TextureLayersDocumentsRepositoryProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/29.
//
import Foundation
@preconcurrency import MetalKit

@MainActor
public protocol TextureLayersDocumentsRepositoryProtocol: AnyObject {

    var workingDirectoryURL: URL { get }

    func initializeStorage(
        newTextureLayersState: TextureLayersState
    ) async throws

    func restoreStorageFromCoreData(
        textureLayersState: TextureLayersState
    ) throws

    func restoreStorageFromSavedData(
        url sourceFolderURL: URL,
        textureLayersState: TextureLayersState
    ) async throws

    func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture
    func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture]

    func removeAll()
    func removeTexture(_ id: LayerId) throws

    func addTexture(texture: MTLTexture, id: LayerId) async throws
    func writeTextureToDisk(texture: MTLTexture, for id: LayerId) async throws
}
