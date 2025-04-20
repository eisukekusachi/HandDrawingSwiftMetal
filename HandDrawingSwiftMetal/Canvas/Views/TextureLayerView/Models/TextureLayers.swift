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

    var initializeCanvasWithModelPublisher: AnyPublisher<CanvasModel, Never> {
        initializeCanvasWithModelSubject.eraseToAnyPublisher()
    }
    private let initializeCanvasWithModelSubject = PassthroughSubject<CanvasModel, Never>()

    var updateCanvasAfterTextureLayerUpdatesPublisher: AnyPublisher<Void, Never> {
        updateCanvasAfterTextureLayerUpdatesSubject.eraseToAnyPublisher()
    }
    var updateCanvasPublisher: AnyPublisher<Void, Never> {
        updateCanvasSubject.eraseToAnyPublisher()
    }
    private let updateCanvasAfterTextureLayerUpdatesSubject = PassthroughSubject<Void, Never>()
    private let updateCanvasSubject = PassthroughSubject<Void, Never>()

    let initializeWithTextureSizeSubject = PassthroughSubject<CGSize, Never>()

    var drawableTextureSize: CGSize = MTLRenderer.minimumTextureSize {
        didSet {
            if drawableTextureSize < MTLRenderer.minimumTextureSize {
                drawableTextureSize = MTLRenderer.minimumTextureSize
            }
        }
    }

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

        initializeWithTextureSizeSubject
            .sink { [weak self] textureSize in
                self?.initializeWithTextureSize(textureSize)
            }
            .store(in: &cancellables)
    }

    /// Attempts to restore layers from a given `CanvasModel`
    /// If the model is invalid, initialization is performed using the given texture size
    func restoreLayers(from model: CanvasModel, drawableSize: CGSize) {
        drawableTextureSize = drawableSize

        textureRepository?.hasAllTextures(for: model.layers.map { $0.id })
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] allExist in
                guard let `self` else { return }
                if allExist {
                    self.initializeCanvasWithModelSubject.send(model)
                } else {
                    self.initializeWithTextureSizeSubject.send(
                        model.getTextureSize(drawableTextureSize: self.drawableTextureSize)
                    )
                }
            })
            .store(in: &cancellables)
    }

    private func initializeWithModel(_ model: CanvasModel) {
        guard
            let textureSize = model.textureSize,
            textureSize > MTLRenderer.minimumTextureSize
        else { return }

        initializeCanvasWithModelSubject.send(model)
    }

    private func initializeWithTextureSize(_ textureSize: CGSize) {
        guard textureSize > MTLRenderer.minimumTextureSize else { return }

        let layer = TextureLayerModel(
            title: TimeStampFormatter.currentDate
        )

        textureRepository?.initTexture(
            uuid: layer.id,
            textureSize: textureSize
        )
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished: break
            case .failure: break
            }
        }, receiveValue: { [weak self] in
            self?.initializeCanvasWithModelSubject.send(
                CanvasModel(textureSize: textureSize, layers: [layer])
            )
        })
        .store(in: &cancellables)
    }

}

extension TextureLayers {

    func insertLayer(textureSize: CGSize, at index: Int) {
        guard let textureRepository else { return }
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
                self?.updateCanvasAfterTextureLayerUpdatesSubject.send(())
            })
            .store(in: &cancellables)
    }

    func removeLayer() {
        guard
            let textureRepository,
            let selectedLayerId = canvasState.selectedLayer?.id,
            let index = canvasState.layers.firstIndex(where: { $0.id == selectedLayerId })
        else { return }

        let newSelectedLayerId = canvasState.layers[max(index - 1, 0)].id

        removeLayerPublisher(from: index)
            .flatMap { removedTextureId -> AnyPublisher<UUID, Never> in
                textureRepository.removeTexture(removedTextureId)
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] _ in
                self?.canvasState.selectedLayerId = newSelectedLayerId
                self?.updateCanvasAfterTextureLayerUpdatesSubject.send(())
            })
            .store(in: &cancellables)
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        textureRepository?.getThumbnail(uuid)
    }

    func selectLayer(_ uuid: UUID) {
        canvasState.selectedLayerId = uuid
        updateCanvasAfterTextureLayerUpdatesSubject.send(())
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

        updateCanvasAfterTextureLayerUpdatesSubject.send(())
    }

    func updateLayer(
        id: UUID,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard let index = canvasState.layers.firstIndex(where: { $0.id == id }) else { return }

        if let title {
            canvasState.layers[index].title = title
        }
        if let isVisible {
            canvasState.layers[index].isVisible = isVisible

            // The visibility of the layers can be changed, so other layers will be updated
            updateCanvasAfterTextureLayerUpdatesSubject.send(())
        }
        if let alpha {
            canvasState.layers[index].alpha = alpha

            // Only the alpha of the selected layer can be changed, so other layers will not be updated
            updateCanvasSubject.send(())
        }
    }

    func updateThumbnail(_ selectedTexture: MTLTexture) {
        guard let selectedLayerId = canvasState.selectedLayerId else { return }

        textureRepository?.setThumbnail(
            texture: selectedTexture,
            for: selectedLayerId
        )

        objectWillChange.send()
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
