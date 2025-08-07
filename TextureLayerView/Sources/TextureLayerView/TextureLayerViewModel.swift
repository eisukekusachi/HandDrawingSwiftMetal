//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import CanvasView
import Combine
import MetalKit

@MainActor
public final class TextureLayerViewModel: ObservableObject {

    @Published public var arrowX: CGFloat = 0

    @Published public var alphaSliderValue: Int = 0

    private var oldValue: Float?

    @Published public var isHandleDragging: Bool = false

    var selectedLayer: TextureLayerModel? {
        canvasState?.selectedLayer
    }

    private(set) var canvasState: CanvasState?

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            if let selectedLayerId, let layer = canvasState?.layer(selectedLayerId) {
                alphaSliderValue = layer.alpha
            }
        }
    }

    private var textureRepository: TextureRepository!

    private var undoStack: UndoStack?

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func initialize(
        configuration: TextureLayerConfiguration
    ) {
        self.canvasState = configuration.canvasState
        self.textureRepository = configuration.textureRepository
        self.undoStack = configuration.undoStack

        subscribe()
    }

    private func subscribe() {
        // Bind the drag gesture of the alpha slider
        $isHandleDragging
            .sink { [weak self] startDragging in
                self?.addUndoAlphaObject(dragging: startDragging)
            }
            .store(in: &cancellables)

        // Bind the value of the alpha slider
        $alphaSliderValue
            .sink { [weak self] value in
                guard let selectedLayerId = self?.selectedLayerId else { return }
                self?.updateLayer(
                    id: selectedLayerId,
                    alpha: Int(value)
                )
            }
            .store(in: &cancellables)

        // Bind `canvasState.selectedLayerId` to `selectedLayerId`
        canvasState?.$selectedLayerId.assign(to: \.selectedLayerId, on: self)
            .store(in: &cancellables)
    }
}

public extension TextureLayerViewModel {

    func onTapInsertButton() {
        guard
            let selectedIndex = canvasState?.selectedIndex,
            let textureSize = canvasState?.getTextureSize(),
            let device: MTLDevice = MTLCreateSystemDefaultDevice()
        else { return }

        let layer: TextureLayerItem = .init(
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )
        let index = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)

        Task {
            let result = try await textureRepository
                .addTexture(
                    MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
                    newTextureUUID: layer.id
                )
            insertLayer(layer: layer, at: index, undoTexture: result.texture)

            canvasState?.updateThumbnail(
                .init(uuid: layer.id, texture: result.texture)
            )
        }
    }

    func onTapDeleteButton() {
        guard
            canvasState?.layers.count ?? 0 > 1,
            let selectedLayer = canvasState?.selectedLayer,
            let selectedIndex = canvasState?.selectedIndex,
            let textureLayerId = canvasState?.layers[selectedIndex].id
        else { return }

        Task {
            let result = try await textureRepository.copyTexture(
                uuid: textureLayerId
            )

            textureRepository
                .removeTexture(selectedLayer.id)

            removeLayer(selectedLayerIndex: selectedIndex, selectedLayer: selectedLayer, undoTexture: result.texture)

            if let layerId = canvasState?.selectedLayerId {
                let result = try await textureRepository.copyTexture(uuid: layerId)
                canvasState?.updateThumbnail(
                    .init(uuid: layerId, texture: result.texture)
                )
            }
        }
    }

    func onTapTitleButton(id: UUID, title: String) {
        updateLayer(id: id, title: title)
    }

    func onTapVisibleButton(id: UUID, isVisible: Bool) {
        updateLayer(id: id, isVisible: isVisible)
    }

    func onTapCell(id: UUID) {
        selectLayer(layerId: id)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        moveLayer(indices: .init(sourceIndexSet: source, destinationIndex: destination))
    }
}

// MARK: CRUD
public extension TextureLayerViewModel {

    private func insertLayer(layer: TextureLayerItem, at index: Int, undoTexture: MTLTexture?) {
        let previousLayerIndex = self.canvasState?.selectedIndex ?? 0

        // Perform a layer operation
        canvasState?.layers.insert(
            .init(
                item: layer,
                thumbnail: nil
            ),
            at: index
        )
        canvasState?.selectedLayerId = layer.id
        canvasState?.fullCanvasUpdateSubject.send(())

        // Push an UndoObject onto the stack
        Task {
            let currentLayerIndex = canvasState?.selectedIndex ?? 0
            await addUndoAdditionObject(
                previousLayerIndex: previousLayerIndex,
                currentLayerIndex: currentLayerIndex,
                layer: layer,
                texture: undoTexture
            )
        }
    }

    private func removeLayer(selectedLayerIndex: Int, selectedLayer: TextureLayerModel, undoTexture: MTLTexture?) {
        guard let canvasState else { return }

        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedLayerIndex)

        // Perform a layer operation
        canvasState.layers.remove(at: selectedLayerIndex)
        canvasState.selectedLayerId = canvasState.layers[newLayerIndex].id
        canvasState.fullCanvasUpdateSubject.send(())

        // Push an UndoObject onto the stack
        Task {
            await addUndoDeletionObject(
                previousLayerIndex: selectedLayerIndex,
                currentLayerIndex: newLayerIndex,
                layer: .init(model: selectedLayer),
                texture: undoTexture
            )
        }
    }

    private func moveLayer(
        indices: MoveLayerIndices
    ) {
        guard let canvasState else { return }

        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: canvasState.layers.count
        )

        // MARK: Perform a layer operation
        canvasState.layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
        canvasState.fullCanvasUpdateSubject.send(())

        // MARK: Push an UndoObject onto the stack
        guard
            let selectedLayerId = canvasState.selectedLayer?.id,
            let textureLayer = canvasState.layers.first(where: { $0.id == selectedLayerId })
        else { return }
        addUndoMoveObject(
            indices: reversedIndices,
            selectedLayerId: selectedLayerId,
            textureLayer: .init(model: textureLayer)
        )
    }

    private func updateLayer(
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard
            let canvasState,
            let selectedIndex = canvasState.layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = canvasState.layers[selectedIndex]

        if let title {
            canvasState.layers[selectedIndex] = .init(
                id: layer.id,
                thumbnail: layer.thumbnail,
                title: title,
                alpha: layer.alpha,
                isVisible: layer.isVisible
            )
        }
        if let isVisible {
            canvasState.layers[selectedIndex] = .init(
                id: layer.id,
                thumbnail: layer.thumbnail,
                title: layer.title,
                alpha: layer.alpha,
                isVisible: isVisible
            )

            // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
            canvasState.fullCanvasUpdateSubject.send(())
        }
        if let alpha {
            canvasState.layers[selectedIndex] = .init(
                id: layer.id,
                thumbnail: layer.thumbnail,
                title: layer.title,
                alpha: alpha,
                isVisible: layer.isVisible
            )

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            canvasState.canvasUpdateSubject.send(())
        }
    }

    private func selectLayer(layerId: UUID) {
        canvasState?.selectedLayerId = layerId
        canvasState?.fullCanvasUpdateSubject.send(())
    }

}

private extension TextureLayerViewModel {

    func addUndoAdditionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerItem,
        texture: MTLTexture?
    ) async {
        guard let canvasState else { return }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            insertIndex: currentLayerIndex
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: canvasState.layers[previousLayerIndex].id
        )

        await undoStack?.pushUndoAdditionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    func addUndoDeletionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerItem,
        texture: MTLTexture?
    ) async {
        guard let canvasState else { return }

        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: canvasState.layers[currentLayerIndex].id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            layerToBeAdded: redoObject.textureLayer,
            insertIndex: previousLayerIndex
        )

        await undoStack?.pushUndoDeletionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    func addUndoMoveObject(
        indices: MoveLayerIndices,
        selectedLayerId: UUID,
        textureLayer: TextureLayerItem
    ) {
        let redoObject = UndoMoveObject(
            indices: indices,
            selectedLayerId: selectedLayerId,
            layer: textureLayer
        )

        let undoObject = redoObject.reversedObject

        undoStack?.pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    func addUndoAlphaObject(dragging: Bool) {
        guard let canvasState else { return }

        if dragging, let alpha = canvasState.selectedLayer?.alpha {
            self.oldValue = Float(alpha)
        } else {
            if let oldAlpha = self.oldValue,
               let newAlpha = canvasState.selectedLayer?.alpha,
               let selectedLayer = canvasState.selectedLayer {

                let undoObject = UndoAlphaChangedObject(
                    layer: .init(model: selectedLayer),
                    withNewAlpha: Int(oldAlpha)
                )

                undoStack?.pushUndoObject(
                    .init(
                        undoObject: undoObject,
                        redoObject: UndoAlphaChangedObject(
                            layer: undoObject.textureLayer,
                            withNewAlpha: newAlpha
                        )
                    )
                )
            }

            self.oldValue = nil
        }
    }
}
