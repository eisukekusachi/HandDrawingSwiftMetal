//
//  TextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import UIKit

@MainActor
public class TextureLayerViewModel: ObservableObject {

    @Published public var currentAlpha: Int = 0

    @Published public var isAlphaSliderDragging: Bool = false

    public let onLayersChanged: ((TextureLayerEvent) -> Void)?

    public var selectedLayer: TextureLayerItem? {
        textureLayers.selectedLayer
    }

    @Published private(set) var textureLayers: TextureLayersState = .init()

    private let dependencies: TextureLayerViewDependencies?

    private var cancellables = Set<AnyCancellable>()

    public init(
        dependencies: TextureLayerViewDependencies? = nil,
        onLayersChanged: ((TextureLayerEvent) -> Void)? = nil
    ) {
        self.dependencies = dependencies ?? .init()
        self.onLayersChanged = onLayersChanged
    }

    open func onTapInsertButton(device: MTLDevice?) async throws {
        guard
            let device,
            let selectedIndex = textureLayers.selectedIndex,
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureLayers.textureSize.width),
                height: Int(textureLayers.textureSize.height),
                with: device
            )
        else { return }

        let layer: TextureLayerModel = .init(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )
        try await textureLayers.addLayer(
            layer: layer,
            thumbnail: newTexture.makeThumbnail(),
            at: AddLayerIndex.insertIndex(selectedIndex: selectedIndex)
        )
        try await dependencies?.textureLayersDocumentsRepository
            .addTexture(
                texture: newTexture,
                id: layer.id,
                device: device
            )
        onLayersChanged?(.addLayer)
    }

    open func onTapDeleteButton() async throws {
        guard
            let selectedIndex = textureLayers.selectedIndex,
            let selectedId = textureLayers.selectedLayer?.id,
            textureLayers.layerCount > 1
        else { return }

        try await textureLayers.removeLayer(
            layerIndexToDelete: selectedIndex
        )
        try dependencies?.textureLayersDocumentsRepository
            .removeTexture(
                selectedId
            )
        onLayersChanged?(.removeLayer)
    }

    open func onTapTitleButton(_ id: UUID, title: String) {
        textureLayers.updateTitle(id, title: title)
    }

    open func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        textureLayers.updateVisibility(id, isVisible: isVisible)
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

    func update(
        _ textureLayers: TextureLayersState,
        device: MTLDevice? = nil
    ) {
        self.textureLayers = textureLayers

        // Update the thumbails
        Task { [weak self] in
            for layer in textureLayers.layers {
                guard let device else { return }
                let layerId: LayerId = layer.id
                let texture = try? await self?.dependencies?.textureLayersDocumentsRepository.duplicatedTexture(
                    layerId,
                    device: device
                )
                textureLayers.updateThumbnail(layerId, texture: texture?.texture)
            }
        }

        // Update the alpha slider handle position
        self.updateCurrentAlpha()

        // Avoid multiple subscriptions
        cancellables.removeAll()

        self.textureLayers.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
