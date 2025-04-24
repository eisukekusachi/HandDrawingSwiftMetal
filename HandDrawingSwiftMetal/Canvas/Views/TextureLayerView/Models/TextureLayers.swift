//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import Combine
import MetalKit

/// Manage texture layers using `CanvasState` and `TextureRepository`
final class TextureLayers: ObservableObject {

    @Published private(set) var layers: [TextureLayerModel] = []

    @Published private(set) var selectedLayerId: UUID?

    private var canvasState: CanvasState

    private var textureRepository: (any TextureRepository)!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var cancellables = Set<AnyCancellable>()

    init(
        canvasState: CanvasState,
        textureRepository: (any TextureRepository) = SingletonTextureInMemoryRepository.shared
    ) {
        self.canvasState = canvasState
        self.textureRepository = textureRepository

        canvasState.$layers.assign(to: \.layers, on: self)
            .store(in: &cancellables)

        canvasState.$selectedLayerId.assign(to: \.selectedLayerId, on: self)
            .store(in: &cancellables)

        textureRepository.triggerViewUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var selectedLayer: TextureLayerModel? {
        canvasState.selectedLayer
    }

    var selectedIndex: Int? {
        canvasState.selectedIndex
    }

}

extension TextureLayers {

    func insertLayer(at index: Int) {
        guard
            let textureRepository,
            let textureSize = canvasState.currentTextureSize
        else { return }

        let device = self.device

        addNewLayerPublisher(at: index)
            .flatMap { textureLayerId in
                textureRepository.updateTexture(
                    texture: MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
                    for: textureLayerId
                )
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] newLayerTextureId in
                self?.canvasState.selectedLayerId = newLayerTextureId
                self?.textureRepository.updateCanvasAfterTextureLayerUpdates()
            })
            .store(in: &cancellables)
    }

    func removeLayer() {
        guard
            let textureRepository,
            let selectedLayerId = canvasState.selectedLayer?.id,
            let selectedIndex = canvasState.selectedIndex
        else { return }

        removeLayerPublisher(from: selectedIndex)
            .flatMap { removedTextureId -> AnyPublisher<UUID, Never> in
                textureRepository.removeTexture(removedTextureId)
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] _ in
                guard let `self` else { return }
                self.canvasState.selectedLayerId = self.canvasState.layers[max(selectedIndex - 1, 0)].id
                self.textureRepository.updateCanvasAfterTextureLayerUpdates()
            })
            .store(in: &cancellables)
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        textureRepository?.getThumbnail(uuid)
    }

    func selectLayer(_ uuid: UUID) {
        canvasState.selectedLayerId = uuid
        textureRepository.updateCanvasAfterTextureLayerUpdates()
    }

}

// MARK: CRUD
extension TextureLayers {

    var newIndex: Int {
        (canvasState.selectedIndex ?? 0) + 1
    }

    func addLayer(at index: Int) -> UUID? {
        guard index >= 0 && index <= canvasState.layers.count else { return nil }

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate
        )
        canvasState.layers.insert(layer, at: index)
        return layer.id
    }
    func removeLayer(from index: Int) -> UUID? {
        guard canvasState.layers.count > 1, canvasState.layers.indices.contains(index) else { return nil }

        let removedLayerId = canvasState.layers[index].id
        canvasState.layers.remove(at: index)
        return removedLayerId
    }

    /// Sort TextureLayers's `layers` based on the values received from `List`
    func moveLayer(
        fromListOffsets: IndexSet,
        toListOffset: Int
    ) {
        // Since `textureLayers` and `List` have reversed orders,
        // reverse the array, perform move operations, and then reverse it back
        canvasState.layers.reverse()
        canvasState.layers.move(
            fromOffsets: fromListOffsets,
            toOffset: toListOffset
        )
        canvasState.layers.reverse()

        textureRepository.updateCanvasAfterTextureLayerUpdates()
    }

    func updateLayer(
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

            // The visibility of the layers can be changed, so other layers will be updated
            textureRepository.updateCanvasAfterTextureLayerUpdates()
        }
        if let alpha {
            canvasState.layers[selectedIndex].alpha = alpha

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            textureRepository.updateCanvas()
        }
    }

}

// MARK: Publishers
extension TextureLayers {

    private func addNewLayerPublisher(at index: Int) -> AnyPublisher<UUID, Error> {
        Just(index)
            .tryMap { [weak self] index in
                guard let newLayerId = self?.addLayer(at: index) else {
                    throw TextureLayerError.indexOutOfBounds
                }
                return newLayerId
            }
            .eraseToAnyPublisher()
    }
    func removeLayerPublisher(from index: Int) -> AnyPublisher<UUID, Error> {
        Just(index)
            .tryMap { [weak self] index in
                guard let removeLayerId = self?.removeLayer(from: index) else {
                    throw TextureLayerError.minimumLayerRequired
                }
                return removeLayerId
            }
            .eraseToAnyPublisher()
    }

}

enum TextureLayerError: Error {
    case indexOutOfBounds
    case minimumLayerRequired
    case failedToUnwrap
}
