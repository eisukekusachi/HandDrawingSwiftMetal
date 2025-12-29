//
//  TextureDocumentsDirectoryRepositoryProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/29.
//
import Foundation
@preconcurrency import MetalKit

@MainActor
public protocol TextureDocumentsDirectoryRepositoryProtocol: AnyObject {

    var textureSize: CGSize { get }
    var directoryName: String { get }
    var workingDirectoryURL: URL { get }

    func initializeStorageFromDocumentsFolderFiles(textureLayersState: TextureLayersState) throws

    @discardableResult
    func initializeStorage(newTextureSize: CGSize) async throws -> TextureLayersState

    func restoreStorage(
        from sourceFolderURL: URL,
        textureLayersState: TextureLayersState
    ) async throws

    func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture
    func duplicatedTextures(_ ids: [LayerId]) async throws -> [IdentifiedTexture]

    func removeAll()
    func removeTexture(_ id: LayerId) throws

    func addTexture(texture: MTLTexture, id: LayerId) async throws
    func writeTextureToDisk(texture: MTLTexture, for id: LayerId) async throws
}
