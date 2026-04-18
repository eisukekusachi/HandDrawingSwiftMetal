//
//  UndoDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/09/23.
//

import CanvasView
import Combine
import UIKit
import TextureLayerView

/// A class that manages texture layers with undo functionality
@MainActor
final class UndoDrawing: ObservableObject {

    /// A repository that stores textures for undo operations.
    /// The textures are stored and managed in memory to avoid blocking the main thread.
    private var inMemoryRepository: UndoTextureInMemoryRepositoryProtocol? = nil

    private var renderer: MTLRendering

    /// Holds the previous texture to support undoing drawings
    private var previousDrawingTextureForUndo: MTLTexture?

    /// Holds the previous alpha value to support undoing transparency changes
    private var previousAlphaForUndo: Int?

    private var cancellables = Set<AnyCancellable>()

    init(
        renderer: MTLRendering,
        inMemoryRepository: UndoTextureInMemoryRepositoryProtocol?
    ) {
        self.renderer = renderer
        self.inMemoryRepository = inMemoryRepository
    }

    func initializeUndoTextures(
        textureSize: CGSize
    ) {
        // Create a texture for use in drawing undo operations
        previousDrawingTextureForUndo = renderer.makeTexture(textureSize)
    }

    func setUndoDrawing(
        texture: MTLTexture?
    ) async {
        await setDrawingUndoObject(texture: texture)
    }

    func pushUndoDrawingObject(
        selectedLayer: TextureLayerItem,
        texture: MTLTexture?
    ) async throws -> UndoRedoObjectPair? {
        guard let inMemoryRepository else { return nil }

        guard
            let undoTexture = try await MTLTextureCreator.duplicateTexture(
                texture: previousDrawingTextureForUndo,
                renderer: renderer
            )
        else {
            Logger.error(String(format: String(localized: "Unable to find %@"), "undoTexture"))
            return nil
        }

        guard
            let redoTexture = try await MTLTextureCreator.duplicateTexture(
                texture: texture,
                renderer: renderer
            )
        else {
            Logger.error(String(format: String(localized: "Unable to find %@"), "redoTexture"))
            return nil
        }

        let undoObject = UndoDrawingObject(
            layer: .init(item: selectedLayer)
        )
        let redoObject = UndoDrawingObject(
            layer: .init(item: selectedLayer)
        )

        guard
            let undoTextureId = undoObject.undoTextureId,
            let redoTextureId = redoObject.undoTextureId
        else { return nil }

        do {
            try await inMemoryRepository
                .addTexture(
                    newTexture: undoTexture,
                    id: undoTextureId
                )
            try await inMemoryRepository
                .addTexture(
                    newTexture: redoTexture,
                    id: redoTextureId
                )

            return .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        } catch {
            // No action on error
            Logger.error(error)
        }

        return nil
    }
}

private extension UndoDrawing {

    func setDrawingUndoObject(
        texture: MTLTexture?
    ) async {
        guard
            let texture,
            let previousDrawingTextureForUndo
        else {
            Logger.error(String(format: String(localized: "Unable to find %@"), "previousDrawingTextureForUndo"))
            return
        }

        do {
            try await renderer.copyTexture(
                srcTexture: texture,
                dstTexture: previousDrawingTextureForUndo,
            )
        } catch {
            // No action on error
            Logger.error(error)
        }
    }
}
