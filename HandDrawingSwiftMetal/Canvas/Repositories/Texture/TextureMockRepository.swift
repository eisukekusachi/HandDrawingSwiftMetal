//
//  TextureMockRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/21.
//

import Combine
import UIKit
import Metal

final class TextureMockRepository: TextureRepository {

    var needsCanvasInitializationAfterNewTextureCreationPublisher: AnyPublisher<CGSize, Never> {
        needsCanvasInitializationAfterNewTextureCreationSubject.eraseToAnyPublisher()
    }
    var needsCanvasInitializationUsingConfigurationPublisher: AnyPublisher<CanvasConfiguration, Never> {
        needsCanvasInitializationUsingConfigurationSubject.eraseToAnyPublisher()
    }

    var needsCanvasUpdateAfterTextureLayersUpdatedPublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.eraseToAnyPublisher()
    }
    var needsCanvasUpdatePublisher: AnyPublisher<Void, Never> {
        needsCanvasUpdateSubject.eraseToAnyPublisher()
    }

    /// Emit `UUID` when the thumbnail is updated
    var needsThumbnailUpdatePublisher: AnyPublisher<UUID, Never> {
        needsThumbnailUpdateSubject.eraseToAnyPublisher()
    }

    private let needsCanvasInitializationAfterNewTextureCreationSubject = PassthroughSubject<CGSize, Never>()

    private let needsCanvasInitializationUsingConfigurationSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsCanvasUpdateAfterTextureLayersUpdatedSubject = PassthroughSubject<Void, Never>()

    private let needsCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private let needsThumbnailUpdateSubject: PassthroughSubject<UUID, Never> = .init()

    var textureNum: Int = 0

    var textureSize: CGSize = .zero

    func resolveCanvasView(from configuration: CanvasConfiguration, drawableSize: CGSize) {}

    func hasAllTextures(for uuids: [UUID]) -> AnyPublisher<Bool, any Error> {
        Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func initializeCanvasAfterCreatingNewTexture(_ textureSize: CGSize) {
        
    }

    func createTexture(uuid: UUID, textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func createTextures(layers: [TextureLayerModel], textureSize: CGSize, folderURL: URL) -> AnyPublisher<Void, any Error> {
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        nil
    }

    func loadTexture(_ uuid: UUID) -> AnyPublisher<(any MTLTexture)?, any Error> {
        Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func loadTextures(_ uuids: [UUID]) -> AnyPublisher<[UUID : (any MTLTexture)?], any Error> {
        let result = uuids.reduce(into: [UUID: MTLTexture?]()) { $0[$1] = nil }
        return Just(result)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Never> {
        Just(uuid)
            .eraseToAnyPublisher()
    }

    func removeAll() {}

    func setThumbnail(texture: (any MTLTexture)?, for uuid: UUID) {}

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) -> AnyPublisher<UUID, any Error> {
        Just(uuid)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateCanvasAfterTextureLayerUpdates() {
        needsCanvasUpdateAfterTextureLayersUpdatedSubject.send()
    }

    func updateCanvas() {
        needsCanvasUpdateSubject.send()
    }

}
