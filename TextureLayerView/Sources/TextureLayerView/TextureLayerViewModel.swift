//
//  Created by Eisuke Kusachi
//

import Combine
import Foundation

@MainActor
final class TextureLayerViewModel: ObservableObject {

    @Published private(set) var currentAlpha: Int = 0

    var layers: [TextureLayerItem] {
        textureLayers.layers
    }

    private var selectedLayerId: LayerId? {
        textureLayers.selectedLayerId
    }

    private let textureLayers: any TextureLayersProtocol

    let onClose: (() -> Void)?

    private let onError: ((Error) -> Void)?

    var selectedLayer: TextureLayerItem? {
        guard let selectedLayerId else { return nil }
        return layers.first { $0.id == selectedLayerId }
    }

    private static var alphaRange: ClosedRange<Int> { 0...255 }

    private var cancellables = Set<AnyCancellable>()

    init(
        textureLayers: any TextureLayersProtocol,
        onClose: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.textureLayers = textureLayers
        self.onClose = onClose
        self.onError = onError
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
    func onTapInsertButton() async -> Bool {
        guard selectedLayerId != nil else { return false }
        do {
            try await textureLayers.addLayer()
            return true
        } catch {
            onError?(error)
            return false
        }
    }

    @discardableResult
    func onTapDeleteButton() async -> Bool {
        guard
            let selectedId = selectedLayer?.id,
            layers.count > 1
        else { return false }
        do {
            guard try await textureLayers.removeLayer(id: selectedId) else { return false }
            return true
        } catch {
            onError?(error)
            return false
        }
    }

    func onTapTitleButton(_ id: UUID, title: String) {
        do {
            try textureLayers.renameLayer(id: id, title: title)
        } catch {
            onError?(error)
        }
    }

    func onTapVisibleButton(_ id: UUID, isVisible: Bool) {
        do {
            try textureLayers.setVisibility(id: id, isVisible: isVisible)
        } catch {
            onError?(error)
        }
    }

    func onTapCell(_ id: UUID) {
        do {
            try textureLayers.selectLayer(id: id)
        } catch {
            onError?(error)
        }
    }

    func onMoveLayer(source: IndexSet, destination: Int) {
        do {
            try textureLayers.moveLayers(from: source, to: destination)
        } catch {
            onError?(error)
        }
    }

    func onAlphaSliderDragging(_ isDragging: Bool) {
        textureLayers.setAlphaSliderDragging(isDragging)
    }

    func onChangeCurrentAlpha(_ alpha: Int) {
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

    func isSelected(_ id: UUID) -> Bool {
        selectedLayerId == id
    }
}

private extension TextureLayerViewModel {

    static func clampedAlpha(_ alpha: Int) -> Int {
        min(max(alphaRange.lowerBound, alpha), alphaRange.upperBound)
    }

    func updateCurrentAlpha() {
        guard let layer = selectedLayer else { return }
        setCurrentAlpha(layer.alpha)
    }
}
