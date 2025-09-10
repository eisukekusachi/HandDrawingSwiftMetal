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
        textureLayers?.selectedLayer
    }

    private(set) var textureLayers: TextureLayers?

    private(set) var defaultBackgroundColor: UIColor = .white
    private(set) var selectedBackgroundColor: UIColor = .black

    @Published private var selectedLayerId: UUID? {
        didSet {
            // Update the slider value when selectedLayerId changes
            if let selectedLayerId, let layer = textureLayers?.layer(selectedLayerId) {
                currentAlpha = layer.alpha
            }
        }
    }

    private var textureRepository: TextureRepository!

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func initialize(
        configuration: TextureLayerConfiguration
    ) {
        textureLayers = configuration.textureLayers
        defaultBackgroundColor = configuration.defaultBackgroundColor
        selectedBackgroundColor = configuration.selectedBackgroundColor

        subscribe()
    }

    private func subscribe() {
        // Bind the drag gesture of the alpha slider
        $isDragging
            .sink { [weak self] startDragging in
                self?.textureLayers?.addUndoAlphaObject(
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
                self?.textureLayers?.updateLayer(
                    id: selectedLayerId,
                    alpha: Int(value)
                )
            }
            .store(in: &cancellables)

        // Bind `canvasState.selectedLayerId` to `selectedLayerId`
        textureLayers?.$selectedLayerId.assign(to: \.selectedLayerId, on: self)
            .store(in: &cancellables)

        textureLayers?.$layers
            .receive(on: DispatchQueue.main)
            .assign(to: &$layers)
    }
}

public extension TextureLayerViewModel {

    func isSelected(_ uuid: UUID) -> Bool {
        textureLayers?.selectedLayer?.id == uuid
    }

    func onTapInsertButton() {
        guard
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex,
            let device: MTLDevice = MTLCreateSystemDefaultDevice()
        else { return }

        let texture = MTLTextureCreator.makeTexture(
            width: Int(textureLayers.currentTextureSize.width),
            height: Int(textureLayers.currentTextureSize.height),
            with: device
        )

        let layer: TextureLayerItem = .init(
            id: UUID(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true,
            thumbnail: texture?.makeThumbnail()
        )
        let index = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)

        Task {
            do {
                try await textureLayers.addLayer(
                    newTextureLayer: layer,
                    texture: texture,
                    at: index
                )
            } catch {

            }
        }
    }

    func onTapDeleteButton() {
        guard
            let textureLayers,
            let selectedIndex = textureLayers.selectedIndex,
            textureLayers.layers.count > 1
        else { return }

        Task {
            try await textureLayers.removeLayer(layerIdToDelete: selectedIndex)
        }
    }

    func onTapTitleButton(id: UUID, title: String) {
        textureLayers?.updateLayer(id: id, title: title)
    }

    func onTapVisibleButton(id: UUID, isVisible: Bool) {
        textureLayers?.updateLayer(id: id, isVisible: isVisible)
    }

    func onTapCell(id: UUID) {
        textureLayers?.selectLayer(id: id)
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        Task {
            await textureLayers?.moveLayer(
                indices: .init(
                    sourceIndexSet: source,
                    destinationIndex: destination
                )
            )
        }
    }
}
