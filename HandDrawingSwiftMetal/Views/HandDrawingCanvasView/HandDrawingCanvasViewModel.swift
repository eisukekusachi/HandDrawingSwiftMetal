//
//  HandDrawingCanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/02/04.
//

import CanvasView
import Combine
import Foundation
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class HandDrawingCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    let performUndoSubject = PassthroughSubject<UndoObject, Never>()

    let updateCanvasTextureSubject = PassthroughSubject<MTLTexture?, Never>()

    let updateFullCanvasTextureSubject = PassthroughSubject<Void, Never>()

    let textureLayersState: TextureLayersState = TextureLayersState()

    let undoDrawing: UndoDrawing?

    private let textureLayerStorage: CoreDataTextureLayerStorage

    private let dependencies: HandDrawingCanvasViewDependencies

    private let textureLayersStorageController: PersistenceController = PersistenceController(
        xcdatamodeldName: "TextureLayerStorage"
    )

    private var cancellables = Set<AnyCancellable>()

    private var restoredDataFromCoreData: TextureLayersModel? {
        guard
            let entity = textureLayerStorage.fetch()
        else { return nil }
        return textureLayerStorage.textureLayersModel(from: entity)
    }

    private var renderer: MTLRendering

    init(
        renderer: MTLRendering,
        dependencies: HandDrawingCanvasViewDependencies? = nil
    ) {
        self.dependencies = dependencies ?? .init()
        self.textureLayerStorage = .init(
            textureLayers: textureLayersState,
            context: textureLayersStorageController.viewContext
        )
        self.renderer = renderer
        self.undoDrawing = .init(
            renderer: self.renderer,
            inMemoryRepository: self.dependencies.undoTextureInMemoryRepository
        )
    }
}

extension HandDrawingCanvasViewModel {
    func restoreOrInitializeTextureLayers(
        fallbackTextureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async -> CGSize {
        let textureLayersData: TextureLayersModel
        let resolvedTextureSize: CGSize

        if let restoredDataFromCoreData {
            do {
                try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
                    textureLayers: restoredDataFromCoreData,
                    device: renderer.device
                )
                textureLayersData = restoredDataFromCoreData
                resolvedTextureSize = restoredDataFromCoreData.textureSize

            } catch {
                // Initialize using the configuration values when an error occurs
                let newData = await initalizeStorage(
                    textureSize: fallbackTextureSize,
                    commandQueue: commandQueue
                )
                textureLayersData = newData
                resolvedTextureSize = fallbackTextureSize

                // Initialize the Core Data storage if fetching fails
                textureLayerStorage.clearAll()
            }
        } else {
            let newData = await initalizeStorage(
                textureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )
            textureLayersData = newData
            resolvedTextureSize = fallbackTextureSize
        }

        textureLayersState.update(textureLayersData)

        return resolvedTextureSize
    }

    private func initalizeStorage(
        textureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async -> TextureLayersModel {
        let data = TextureLayersModel(textureSize: textureSize)
        do {
            try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                textureLayers: data,
                device: renderer.device,
                commandQueue: commandQueue
            )
        } catch {
            fatalError("Failed to initialize storage")
        }
        return data
    }

    func onSaveFiles(
        thumbnail: UIImage?,
        to workingDirectoryURL: URL
    ) async throws {
        do {
            // Save the thumbnail image into the working directory
            try thumbnail?.pngData()?.write(
                to: workingDirectoryURL.appendingPathComponent("thumbnail.png")
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create the thumbnail")
            )
            Logger.error(error)
            throw error
        }

        do {
            // Copy the texture files into the working directory
            for layer in textureLayersState.layers {
                try await dependencies.textureLayersDocumentsRepository.copyTexture(
                    id: layer.id,
                    to: workingDirectoryURL
                )
            }
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create the textures")
            )
            Logger.error(error)
            throw error
        }

        do {
            // Save the texture layers as JSON
            try TextureLayersArchiveModel(
                layers: textureLayersState.layers.map { .init(item: $0) },
                layerIndex: textureLayersState.selectedIndex ?? 0,
                textureSize: textureLayersState.textureSize
            ).write(
                in: workingDirectoryURL
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to save the texture layers")
            )
            Logger.error(error)
            throw error
        }
    }

    func onLoadFiles(
        from workingDirectoryURL: URL
    ) async throws {
        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let data: TextureLayersModel = try .init(model: textureLayersArchiveModel)

        guard try await dependencies.textureLayersDocumentsRepository.restoreStorage(
            url: workingDirectoryURL,
            textureLayers: data,
            device: renderer.device
        ) else {
            return
        }

        textureLayersState.update(data)
    }

    func onNewCanvas() async throws {
        let textureSize = textureLayersState.textureSize

        let data: TextureLayersModel = .init(
            textureSize: textureSize
        )

        guard try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            textureLayers: data,
            device: renderer.device,
            commandQueue: renderer.commandQueue
        ) else {
            return
        }

        textureLayersState.update(data)
    }
}

extension HandDrawingCanvasViewModel {

    func performDrawingUndo(
        _ undoObject: UndoDrawingObject
    ) async {
        guard
            let undoTextureId = undoObject.undoTextureId,
            let newTexture = try? await MTLTextureCreator.duplicateTexture(
                texture: dependencies.undoTextureInMemoryRepository.texture(undoTextureId),
                renderer: renderer
            )
        else { return }

        do {
            let textureLayerId = undoObject.textureLayer.id
            textureLayersState.selectLayer(textureLayerId)

            try await saveTextureToDocumentsDirectory(
                layerId: textureLayerId,
                texture: newTexture
            )
            textureLayersState.updateThumbnail(textureLayerId, texture: newTexture)

            updateCanvasTextureSubject.send(newTexture)

        } catch {
            Logger.error(error)
        }
    }

    func performAdditionUndo(
        _ undoObject: UndoAdditionObject
    ) async {
        guard
            let undoTextureId = undoObject.undoTextureId,
            let newTexture = try? await MTLTextureCreator.duplicateTexture(
                texture: dependencies.undoTextureInMemoryRepository.texture(undoTextureId),
                renderer: renderer
            )
        else { return }

        do {
            try await saveTextureToDocumentsDirectory(
                layerId: undoObject.textureLayer.id,
                texture: newTexture
            )

            textureLayersState.addLayer(
                layer: undoObject.textureLayer,
                thumbnail: newTexture.makeThumbnail(),
                at: undoObject.insertIndex
            )

            updateFullCanvasTextureSubject.send()

        } catch {
            Logger.error(error)
        }
    }

    func performDeletionUndo(
        _ undoObject: UndoDeletionObject
    ) {
        guard
            let index = textureLayersState.layers.firstIndex(
                where: { $0.id == undoObject.textureLayer.id }
            )
        else {
           return
        }

        textureLayersState.removeLayer(
            layerIndexToDelete: index
        )
        updateFullCanvasTextureSubject.send()
    }

    func performMoveUndo(
        _ undoObject: UndoMoveObject
    ) {
        textureLayersState.moveLayer(
            indices: undoObject.indices
        )
        updateFullCanvasTextureSubject.send()
    }

    func performSelectUndo(
        _ undoObject: UndoSelectionObject
    ) async {
        textureLayersState.selectLayer(
            undoObject.textureLayer.id
        )
        updateFullCanvasTextureSubject.send()
    }

    func performAlphaUndo(
        _ undoObject: UndoAlphaObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            alpha: undoObject.textureLayer.alpha
        )
        updateCanvasTextureSubject.send(nil)
    }

    func performVisibilityUndo(
        _ undoObject: UndoVisibilityObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            isVisible: undoObject.textureLayer.isVisible
        )
        updateFullCanvasTextureSubject.send()
    }

    func performTitleUndo(
        _ undoObject: UndoTitleObject
    ) async {
        textureLayersState.update(
            undoObject.textureLayer.id,
            title: undoObject.textureLayer.title
        )
    }

    func registerUndoObjectPair(
        _ undoManager: UndoManager,
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        undoRedoObject.undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                Task {
                    // Do nothing if an error occurs, since nothing can be done
                    try? await self.dependencies.undoTextureInMemoryRepository.removeTexture(
                        undoTextureId
                    )
                }
            })
            .store(in: &cancellables)

        undoRedoObject.redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                Task {
                    // Do nothing if an error occurs, since nothing can be done
                    try? await self.dependencies.undoTextureInMemoryRepository.removeTexture(
                        undoTextureId
                    )
                }
            })
            .store(in: &cancellables)

        undoManager.registerUndo(withTarget: self) { [weak self, undoRedoObject] _ in
            self?.performUndoSubject.send(undoRedoObject.undoObject)

            // Redo Registration
            self?.registerUndoObjectPair(undoManager, undoRedoObject.reversed())
        }
    }

    func clearUndoTextures() {
        Task { [weak self] in
            await self?.dependencies.undoTextureInMemoryRepository.removeAll()
        }
    }

    func duplicateTextureFromDocumentsDirectory(
        _ id: LayerId
    ) async -> MTLTexture? {
        await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            textureSize: textureSize,
            device: renderer.device
        )
    }

    func duplicateTexturesFromDocumentsDirectory(
        _ ids: [LayerId]
    ) async -> [(LayerId, MTLTexture)] {
        await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            textureSize: textureSize,
            device: renderer.device
        )
    }
}

extension HandDrawingCanvasViewModel {

    func saveTextureToDocumentsDirectory(
        layerId: UUID,
        texture: MTLTexture
    ) async throws {
        let textureData = try await texture.data(
            device: renderer.device,
            commandQueue: renderer.commandQueue
        )
        try await dependencies.textureLayersDocumentsRepository.writeDataToDisk(
            id: layerId,
            data: textureData
        )
    }

    func saveTextureToDocumentsDirectory(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await dependencies.textureLayersDocumentsRepository.writeDataToDisk(
            id: layerId,
            data: textureData
        )
    }
}
