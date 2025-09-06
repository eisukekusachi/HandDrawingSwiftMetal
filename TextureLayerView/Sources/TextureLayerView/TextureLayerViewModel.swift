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

    @Published private(set) var layers: [TextureLayerItem] = []

    @Published public var currentAlpha: Int = 0

    @Published public var isDragging: Bool = false

    public var selectedLayer: TextureLayerItem? {
        canvasState?.selectedLayer
    }

    private(set) var canvasState: CanvasState?

    private(set) var defaultBackgroundColor: UIColor = .white
    private(set) var selectedBackgroundColor: UIColor = .black

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            if let selectedLayerId, let layer = canvasState?.layer(selectedLayerId) {
                currentAlpha = layer.alpha
            }
        }
    }

    private var textureRepository: TextureRepository!

    private var layerHandler: LayerHandler?

    private var undoHandler: UndoHandler?

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func initialize(
        configuration: TextureLayerConfiguration
    ) {
        canvasState = configuration.canvasState
        textureRepository = configuration.textureRepository

        defaultBackgroundColor = configuration.defaultBackgroundColor
        selectedBackgroundColor = configuration.selectedBackgroundColor

        layerHandler = .init(canvasState: canvasState)

        undoHandler = .init(canvasState: canvasState, undoStack: configuration.undoStack)

        subscribe()
    }

    private func subscribe() {
        // Bind the drag gesture of the alpha slider
        $isDragging
            .sink { [weak self] startDragging in
                self?.undoHandler?.addUndoAlphaObject(
                    dragging: startDragging
                )
            }
            .store(in: &cancellables)

        // Bind the value of the alpha slider
        $currentAlpha
            .sink { [weak self] value in
                guard
                    let selectedLayerId = self?.selectedLayerId
                else { return }
                self?.layerHandler?.updateLayer(
                    id: selectedLayerId,
                    alpha: Int(value)
                )
            }
            .store(in: &cancellables)

        // Bind `canvasState.selectedLayerId` to `selectedLayerId`
        canvasState?.$selectedLayerId.assign(to: \.selectedLayerId, on: self)
            .store(in: &cancellables)

        canvasState?.$layers
            .receive(on: DispatchQueue.main)
            .assign(to: &$layers)
    }
}

public extension TextureLayerViewModel {

    func isSelected(_ uuid: UUID) -> Bool {
        canvasState?.selectedLayer?.id == uuid
    }

    func onTapInsertButton() {
        guard
            let canvasState,
            let selectedIndex = canvasState.selectedIndex,
            let device: MTLDevice = MTLCreateSystemDefaultDevice()
        else { return }

        let texture = MTLTextureCreator.makeTexture(
            width: Int(canvasState.currentTextureSize.width),
            height: Int(canvasState.currentTextureSize.height),
            with: device
        )

        let thumbnail = texture?.makeThumbnail()

        let layer: TextureLayerItem = .init(
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true,
            thumbnail: thumbnail
        )
        let index = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)
        let previousLayerIndex = canvasState.selectedIndex ?? 0

        layerHandler?.insertLayer(layer: layer, at: index)

        // Add Task to prevent flickering
        Task {
            layerHandler?.selectLayer(id: layer.id)
        }

        Task {
            let result = try await textureRepository
                .addTexture(
                    texture,
                    newTextureUUID: layer.id
                )

            let currentLayerIndex = canvasState.selectedIndex ?? 0
            await undoHandler?.addUndoAdditionObject(
                previousLayerIndex: previousLayerIndex,
                currentLayerIndex: currentLayerIndex,
                layer: .init(
                    fileName: layer.fileName,
                    title: layer.title,
                    alpha: layer.alpha,
                    isVisible: layer.isVisible
                ),
                texture: result.texture
            )
        }
    }

    func onTapDeleteButton() {
        guard
            let canvasState,
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex,
            canvasState.layers.count > 1
        else { return }

        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedIndex)

        layerHandler?.removeLayer(
            selectedLayerIndex: selectedIndex
        )
        Task {
            layerHandler?.selectLayer(id: canvasState.layers[newLayerIndex].id)
        }

        Task {
            let result = try await textureRepository.copyTexture(
                uuid: selectedLayer.id
            )

            await undoHandler?.addUndoDeletionObject(
                previousLayerIndex: selectedIndex,
                currentLayerIndex: newLayerIndex,
                layer: .init(
                    fileName: selectedLayer.fileName,
                    title: selectedLayer.title,
                    alpha: selectedLayer.alpha,
                    isVisible: selectedLayer.isVisible
                ),
                texture: result.texture
            )

            textureRepository
                .removeTexture(selectedLayer.id)
        }
    }

    func onTapTitleButton(id: UUID, title: String) {
        layerHandler?.updateLayer(id: id, title: title)
    }

    func onTapVisibleButton(id: UUID, isVisible: Bool) {
        layerHandler?.updateLayer(id: id, isVisible: isVisible)
    }

    func onTapCell(id: UUID) {
        layerHandler?.selectLayer(id: id)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        guard let canvasState else { return }

        let indices: MoveLayerIndices = .init(
            sourceIndexSet: source,
            destinationIndex: destination
        )

        layerHandler?.moveLayer(indices: indices)

        canvasState.fullCanvasUpdateSubject.send(())

        guard
            let selectedLayerId = canvasState.selectedLayer?.id,
            let textureLayer = canvasState.layers.first(where: { $0.id == selectedLayerId })
        else { return }

        undoHandler?.addUndoMoveObject(
            indices: MoveLayerIndices.reversedIndices(
                indices: indices,
                layerCount: canvasState.layers.count
            ),
            selectedLayerId: selectedLayerId,
            textureLayer: .init(
                fileName: textureLayer.fileName,
                title: textureLayer.title,
                alpha: textureLayer.alpha,
                isVisible: textureLayer.isVisible
            )
        )
    }
}
