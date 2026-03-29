//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import UIKit

@MainActor
open class TextureLayerViewModel: ObservableObject {

    @Published public var currentAlpha: Int = 0

    @Published public var isAlphaSliderDragging: Bool = false

    public let onLayersChanged: ((TextureLayerEvent) -> Void)?

    public var selectedLayer: TextureLayerItem? {
        textureLayers.selectedLayer
    }

    public var textureSize: CGSize {
        textureLayers.textureSize
    }

    @Published public private(set) var textureLayers: TextureLayersState = .init()

    private let device: MTLDevice?

    private let commandQueue: MTLCommandQueue?

    private let dependencies: TextureLayerViewDependencies?

    private var cancellables = Set<AnyCancellable>()

    public init(
        device: MTLDevice?,
        commandQueue: MTLCommandQueue?,
        dependencies: TextureLayerViewDependencies? = nil,
        onLayersChanged: ((TextureLayerEvent) -> Void)? = nil
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.dependencies = dependencies ?? .init()
        self.onLayersChanged = onLayersChanged
    }

    @discardableResult
    open func onTapInsertButton() async throws -> Bool {
        guard
            let device,
            let commandQueue,
            let selectedIndex = textureLayers.selectedIndex,
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else { return false }

        let layer: TextureLayerModel = .init(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )

        let textureData = try await newTexture.data(
            device: device,
            commandQueue: commandQueue
        )
        try dependencies?.textureLayersDocumentsRepository
            .addTextureData(
                data: textureData,
                id: layer.id
            )
        textureLayers.addLayer(
            layer: layer,
            thumbnail: newTexture.makeThumbnail(),
            at: AddLayerIndex.insertIndex(selectedIndex: selectedIndex)
        )

        onLayersChanged?(.addLayer)

        return true
    }

    @discardableResult
    open func onTapDeleteButton() async -> Bool {
        do {
            guard
                let dependencies,
                let selectedIndex = textureLayers.selectedIndex,
                let selectedId = textureLayers.selectedLayer?.id,
                textureLayers.layerCount > 1,
                try dependencies.textureLayersDocumentsRepository
                    .removeTexture(
                        selectedId
                    )
            else { return false }

            textureLayers.removeLayer(
                layerIndexToDelete: selectedIndex
            )
            onLayersChanged?(.removeLayer)

            return true
        } catch {
            Logger.error(error)
            return false
        }
    }

    open func onTapTitleButton(_ id: UUID, title: String) {
        textureLayers.update(id, title: title)
    }

    open func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        textureLayers.update(id, isVisible: isVisible)
        onLayersChanged?(.changeVisibility)
    }

    open func onTapCell(_ id: UUID) {
        textureLayers.selectLayer(id)
        updateCurrentAlpha()
        onLayersChanged?(.selectLayer)
    }

    open func onMoveLayer(source: IndexSet, destination: Int) {
        textureLayers.moveLayer(
            indices: .init(
                sourceIndexSet: source,
                destinationIndex: destination
            )
        )
        onLayersChanged?(.moveLayer)
    }

    open func onChangeCurrentAlpha(_ alpha: Int) {
        guard let selectedLayerId = selectedLayer?.id else { return }
        textureLayers.updateAlpha(selectedLayerId, alpha: alpha)
        updateCurrentAlpha()
        onLayersChanged?(.changeLayerAlpha)
    }
}

public extension TextureLayerViewModel {
    func textureFromDocumentsRepository(_ id: LayerId, device: MTLDevice?) async -> MTLTexture? {
        guard let device else { return nil }
        return await dependencies?.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            device: device
        )
    }

    func update(
        _ textureLayers: TextureLayersState,
        device: MTLDevice? = nil
    ) {
        // Avoid multiple subscriptions
        cancellables.removeAll()

        self.textureLayers = textureLayers

        self.textureLayers.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Update the alpha slider handle position
        updateCurrentAlpha()

        // Update the thumbnails
        if let device, let dependencies {
            Task {
                for layer in textureLayers.layers {
                    let layerId: LayerId = layer.id
                    let texture = await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
                        layerId,
                        device: device
                    )
                    textureLayers.updateThumbnail(layerId, texture: texture)
                }
            }
        }
    }

    func isSelected(_ id: UUID) -> Bool {
        textureLayers.selectedLayer?.id == id
    }
}

extension TextureLayerViewModel {

    private func updateCurrentAlpha() {
        guard
            let selectedLayerId = selectedLayer?.id,
            let layer = textureLayers.layer(selectedLayerId),
            currentAlpha != layer.alpha
        else { return }

        currentAlpha = layer.alpha
    }
}
