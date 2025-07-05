//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import MetalKit

final class TextureLayerViewModel: ObservableObject {

    let alphaSliderValue = SliderValue()

    var selectedLayer: TextureLayerModel? {
        canvasState.selectedLayer
    }

    func thumbnail(_ uuid: UUID) -> UIImage? {
        textureLayerRepository?.thumbnail(uuid)
    }

    private(set) var canvasState: CanvasState

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            if let selectedLayerId, let layer = canvasState.layer(selectedLayerId) {
                alphaSliderValue.value = layer.alpha
            }
        }
    }

    private var textureLayerRepository: TextureLayerRepository!

    private var undoStack: UndoStack?

    private var cancellables = Set<AnyCancellable>()

    init(
        canvasState: CanvasState,
        textureLayerRepository: TextureLayerRepository,
        undoStack: UndoStack?
    ) {
        self.canvasState = canvasState
        self.textureLayerRepository = textureLayerRepository

        self.undoStack = undoStack

        subscribe()
    }

    private func subscribe() {
        // Update the SwiftUI layout
        textureLayerRepository.objectWillChangeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Bind the drag gesture of the alpha slider
        alphaSliderValue.$isHandleDragging
            .sink { [weak self] startDragging in
                self?.addUndoAlphaObject(dragging: startDragging)
            }
            .store(in: &cancellables)

        // Bind the value of the alpha slider
        alphaSliderValue.$value
            .sink { [weak self] value in
                guard let selectedLayerId = self?.selectedLayerId else { return }
                self?.updateLayer(
                    id: selectedLayerId,
                    alpha: value
                )
            }
            .store(in: &cancellables)

        // Bind `canvasState.selectedLayerId` to `selectedLayerId`
        canvasState.$selectedLayerId.assign(to: \.selectedLayerId, on: self)
            .store(in: &cancellables)
    }

}

extension TextureLayerViewModel {

    func onTapInsertButton() {
        guard
            let selectedIndex = canvasState.selectedIndex,
            let device: MTLDevice = MTLCreateSystemDefaultDevice()
        else { return }

        let layer: TextureLayerModel = .init(title: TimeStampFormatter.currentDate)
        let index = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)

        textureLayerRepository
            .addTexture(
                MTLTextureCreator.makeBlankTexture(size: canvasState.textureSize, with: device),
                newTextureUUID: layer.id
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("insertLayer(textureSize:, at:) \(error)")
                    }
                },
                receiveValue: { [weak self] result in
                    self?.insertLayer(layer: layer, at: index, undoTexture: result.texture)
                }
            )
            .store(in: &cancellables)
    }

    func onTapDeleteButton() {
        guard
            canvasState.layers.count > 1,
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex
        else { return }

        textureLayerRepository
            .copyTexture(
                uuid: canvasState.layers[selectedIndex].id
            )
            .flatMap { [weak self] result -> AnyPublisher<IdentifiedTexture, Error> in
                guard let self else {
                    return Fail(error: TextureLayerError.failedToUnwrap).eraseToAnyPublisher()
                }
                return self.textureLayerRepository
                    .removeTexture(selectedLayer.id)
                    .map { _ in result }
                    .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.standard.error("removeLayer() \(error)")
                    }
                },
                receiveValue: { [weak self] result in
                    self?.removeLayer(selectedLayerIndex: selectedIndex, selectedLayer: selectedLayer, undoTexture: result.texture)
                }
            )
            .store(in: &cancellables)
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
extension TextureLayerViewModel {

    private func insertLayer(layer: TextureLayerModel, at index: Int, undoTexture: MTLTexture?) {
        let previousLayerIndex = self.canvasState.selectedIndex ?? 0

        // MARK: Perform a layer operation
        self.canvasState.layers.insert(layer, at: index)
        self.canvasState.selectedLayerId = layer.id
        self.canvasState.fullCanvasUpdateSubject.send(())

        // MARK: Push an UndoObject onto the stack
        let currentLayerIndex = self.canvasState.selectedIndex ?? 0
        self.addUndoAdditionObject(
            previousLayerIndex: previousLayerIndex,
            currentLayerIndex: currentLayerIndex,
            layer: layer,
            texture: undoTexture
        )
    }

    private func removeLayer(selectedLayerIndex: Int, selectedLayer: TextureLayerModel, undoTexture: MTLTexture?) {
        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedLayerIndex)

        // MARK: Perform a layer operation
        self.canvasState.layers.remove(at: selectedLayerIndex)
        self.canvasState.selectedLayerId = self.canvasState.layers[newLayerIndex].id
        self.canvasState.fullCanvasUpdateSubject.send(())

        // MARK: Push an UndoObject onto the stack
        addUndoDeletionObject(
            previousLayerIndex: selectedLayerIndex,
            currentLayerIndex: newLayerIndex,
            layer: selectedLayer,
            texture: undoTexture
        )
    }

    private func moveLayer(
        indices: MoveLayerIndices
    ) {
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
            textureLayer: textureLayer
        )
    }

    private func updateLayer(
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard let selectedIndex = canvasState.layers.map({ $0.id }).firstIndex(of: id) else { return }

        if let title {
            canvasState.layers[selectedIndex].title = title
        }
        if let isVisible {
            canvasState.layers[selectedIndex].isVisible = isVisible

            // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
            canvasState.fullCanvasUpdateSubject.send(())
        }
        if let alpha {
            canvasState.layers[selectedIndex].alpha = alpha

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            canvasState.canvasUpdateSubject.send(())
        }
    }

    private func selectLayer(layerId: UUID) {
        canvasState.selectedLayerId = layerId
        canvasState.fullCanvasUpdateSubject.send(())
    }

}

extension TextureLayerViewModel {

    private func addUndoAdditionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) {
        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            insertIndex: currentLayerIndex
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: canvasState.layers[previousLayerIndex].id
        )

        undoStack?.pushUndoAdditionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    private func addUndoDeletionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) {
        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: canvasState.layers[currentLayerIndex].id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            redoObject,
            insertIndex: previousLayerIndex
        )

        undoStack?.pushUndoDeletionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    private func addUndoMoveObject(
        indices: MoveLayerIndices,
        selectedLayerId: UUID,
        textureLayer: TextureLayerModel
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

    private func addUndoAlphaObject(dragging: Bool) {
        if dragging {
            self.alphaSliderValue.temporaryStoredValue = self.canvasState.selectedLayer?.alpha
        } else {
            if let oldAlpha = self.alphaSliderValue.temporaryStoredValue,
               let newAlpha = self.canvasState.selectedLayer?.alpha,
               let selectedLayer = canvasState.selectedLayer {

                let undoObject = UndoAlphaChangedObject(
                    alpha: oldAlpha,
                    textureLayer: selectedLayer
                )

                undoStack?.pushUndoObject(
                    UndoRedoObject(
                        undoObject: undoObject,
                        redoObject: UndoAlphaChangedObject(undoObject, withNewAlpha: newAlpha)
                    )
                )
            }

            self.alphaSliderValue.temporaryStoredValue = nil
        }
    }

}

enum TextureLayerError: Error {
    case indexOutOfBounds
    case minimumLayerRequired
    case failedToUnwrap
}
