//
//  Created by Eisuke Kusachi
//

import Combine
import Foundation

@MainActor
open class TextureLayerViewModel: ObservableObject {

    private static var alphaRange: ClosedRange<Int> { 0...255 }

    @Published public var currentAlpha: Int = 0

    var layers: [TextureLayerItem] {
        textureLayers.layers
    }

    var selectedLayerId: LayerId? {
        textureLayers.selectedLayerId
    }

    let textureLayers: any TextureLayersProtocol

    var onClose: (() -> Void)?

    var selectedLayer: TextureLayerItem? {
        guard let selectedLayerId else { return nil }
        return layers.first { $0.id == selectedLayerId }
    }

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: any TextureLayersProtocol,
        onClose: (() -> Void)? = nil
    ) {
        self.textureLayers = textureLayers
        self.onClose = onClose
        textureLayers.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.updateCurrentAlpha()
            }
            .store(in: &cancellables)
        updateCurrentAlpha()
    }

    @discardableResult
    open func onTapInsertButton() async throws -> Bool {
        guard selectedLayerId != nil else { return false }
        try await textureLayers.addLayer()
        return true
    }

    @discardableResult
    open func onTapDeleteButton() async throws -> Bool {
        guard
            let selectedId = selectedLayer?.id,
            layers.count > 1,
            try await textureLayers.removeLayer(id: selectedId)
        else { return false }

        return true
    }

    open func onTapTitleButton(_ id: UUID, title: String) throws {
        try textureLayers.renameLayer(id: id, title: title)
    }

    open func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        textureLayers.setVisibility(id: id, isVisible: isVisible)
    }

    open func onTapCell(_ id: UUID) {
        textureLayers.selectLayer(id: id)
    }

    open func onMoveLayer(source: IndexSet, destination: Int) throws {
        try textureLayers.moveLayers(from: source, to: destination)
    }

    func onAlphaSliderDragging(_ isDragging: Bool) {
        textureLayers.setAlphaSliderDragging(isDragging)
    }

    open func onChangeCurrentAlpha(_ alpha: Int) {
        guard let selectedLayerId = selectedLayer?.id else { return }
        let clamped = Self.clampedAlpha(alpha)
        textureLayers.setAlpha(id: selectedLayerId, alpha: clamped)
        setCurrentAlpha(clamped)
    }

    func setCurrentAlpha(_ alpha: Int) {
        let clamped = Self.clampedAlpha(alpha)
        guard currentAlpha != clamped else { return }
        currentAlpha = clamped
    }
}

public extension TextureLayerViewModel {
    func isSelected(_ id: UUID) -> Bool {
        selectedLayerId == id
    }
}

extension TextureLayerViewModel {

    static func clampedAlpha(_ alpha: Int) -> Int {
        min(max(alphaRange.lowerBound, alpha), alphaRange.upperBound)
    }

    private func updateCurrentAlpha() {
        guard let layer = selectedLayer else { return }
        setCurrentAlpha(layer.alpha)
    }
}
