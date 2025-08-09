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

    private var undo: Undo?

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func initialize(
        configuration: TextureLayerConfiguration
    ) {
        self.canvasState = configuration.canvasState
        self.textureRepository = configuration.textureRepository

        self.undo = .init(undoStack: configuration.undoStack)

        subscribe()
    }

    private func subscribe() {
        // Bind the drag gesture of the alpha slider
        $isDragging
            .sink { [weak self] startDragging in
                guard let `self` else { return }
                self.undo?.addUndoAlphaObject(
                    canvasState: self.canvasState,
                    dragging: startDragging
                )
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
                await undo?.addUndoAdditionObject(
                    canvasState: canvasState,
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
                await undo?.addUndoDeletionObject(
                    canvasState: canvasState,
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

        guard
            let selectedLayerId = canvasState.selectedLayer?.id,
            let textureLayer = canvasState.layers.first(where: { $0.id == selectedLayerId })
        else { return }

        undo?.addUndoMoveObject(
            indices: reversedIndices,
            selectedLayerId: selectedLayerId,
            textureLayer: .init(model: textureLayer)
        )
    }
}
