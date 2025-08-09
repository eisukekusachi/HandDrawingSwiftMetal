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

    @Published public var currentAlpha: Int = 0

    @Published var isDragging: Bool = false

    private var oldAlpha: Int?

    var selectedLayer: TextureLayerModel? {
        canvasState?.selectedLayer
    }

    private(set) var canvasState: CanvasState?

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            if let selectedLayerId, let layer = canvasState?.layer(selectedLayerId) {
                currentAlpha = layer.alpha
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
        $isDragging
            .sink { [weak self] startDragging in
                self?.addUndoAlphaObject(dragging: startDragging)
            }
            .store(in: &cancellables)

        // Bind the value of the alpha slider
        $currentAlpha
            .sink { [weak self] value in
                guard
                    let canvasState = self?.canvasState,
                    let selectedLayerId = self?.selectedLayerId
                else { return }
                Layers.updateLayer(
                    canvasState: canvasState,
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
            let canvasState,
            let selectedIndex = canvasState.selectedIndex,
            let device: MTLDevice = MTLCreateSystemDefaultDevice()
        else { return }

        let layer: TextureLayerItem = .init(
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )
        let index = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)
        let previousLayerIndex = canvasState.selectedIndex ?? 0

        Task {
            let texture = MTLTextureCreator.makeBlankTexture(
                size: canvasState.currentTextureSize,
                with: device
            )

            let result = try await textureRepository
                .addTexture(
                    texture,
                    newTextureUUID: layer.id
                )

            Layers.insertLayer(
                canvasState: canvasState,
                layer: layer,
                texture: texture,
                at: index
            )

            // Push an UndoObject onto the stack
            Task {
                let currentLayerIndex = canvasState.selectedIndex ?? 0
                await addUndoAdditionObject(
                    previousLayerIndex: previousLayerIndex,
                    currentLayerIndex: currentLayerIndex,
                    layer: layer,
                    texture: result.texture
                )
            }
        }
    }

    func onTapDeleteButton() {
        guard
            let canvasState,
            canvasState.layers.count > 1,
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex
        else { return }

        Task {
            let result = try await textureRepository.copyTexture(
                uuid: canvasState.layers[selectedIndex].id
            )

            textureRepository
                .removeTexture(selectedLayer.id)

            let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedIndex)

            Layers.removeLayer(
                canvasState: canvasState,
                selectedLayerIndex: selectedIndex,
                selectedLayer: selectedLayer
            )

            Task {
                await addUndoDeletionObject(
                    previousLayerIndex: selectedIndex,
                    currentLayerIndex: newLayerIndex,
                    layer: .init(model: selectedLayer),
                    texture: result.texture
                )
            }
        }
    }

    func onTapTitleButton(id: UUID, title: String) {
        Layers.updateLayer(canvasState: canvasState, id: id, title: title)
    }

    func onTapVisibleButton(id: UUID, isVisible: Bool) {
        Layers.updateLayer(canvasState: canvasState, id: id, isVisible: isVisible)
    }

    func onTapCell(id: UUID) {
        Layers.selectLayer(canvasState: canvasState, layerId: id)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        guard let canvasState else { return }

        let indices: MoveLayerIndices = .init(sourceIndexSet: source, destinationIndex: destination)
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: canvasState.layers.count
        )

        Layers.moveLayer(canvasState: canvasState, indices: indices)

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
}

// MARK: Undo
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
            self.oldAlpha = alpha
        } else {
            if let oldAlpha = self.oldAlpha,
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

            self.oldAlpha = nil
        }
    }
}
