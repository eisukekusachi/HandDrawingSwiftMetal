//
//  TextureLayerInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import MetalKit
import SwiftUI

/// A repository that manages in-memory textures and thumbnails
final class TextureLayerInMemoryRepository: TextureInMemoryRepository, TextureLayerRepository {

    @Published private(set) var thumbnails: [UUID: UIImage?] = [:]

    private let thumbnailUpdateRequestedSubject: PassthroughSubject<UUID, Never> = .init()

    private let device = MTLCreateSystemDefaultDevice()!

    override init(
        textures: [UUID: MTLTexture?] = [:],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        super.init(textures: textures, renderer: renderer)
    }

    /// Clears texture ID data and the thumbnails
    override func removeAll() {
        textures = [:]
        thumbnails = [:]
    }

    override func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        textures.removeValue(forKey: uuid)
        thumbnails.removeValue(forKey: uuid)
        return Just(uuid).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    override func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            do {
                // Delete all data
                self?.removeAll()

                try uuids.forEach { [weak self] uuid in
                    let textureData = try Data(
                        contentsOf: sourceURL.appendingPathComponent(uuid.uuidString)
                    )

                    guard
                        let device = self?.device,
                        let hexadecimalData = textureData.encodedHexadecimals
                    else { return }

                    let texture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: device
                    )

                    self?.textures[uuid] = texture
                    self?.setThumbnail(texture: texture, for: uuid)
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    override func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            if let texture {
                self?.textures[uuid] = texture
                self?.setThumbnail(texture: texture, for: uuid)

                promise(.success(uuid))
            } else {
                promise(.failure(TextureRepositoryError.failedToAddTexture))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerInMemoryRepository {

    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> {
        thumbnailUpdateRequestedSubject.eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future { promise in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let `self` else { return }

                for (uuid, texture) in self.textures {
                    guard let texture else { return }
                    self.setThumbnail(texture: texture, for: uuid)
                }

                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerInMemoryRepository {

    private func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        thumbnails[uuid] = texture?.makeThumbnail()
        thumbnailUpdateRequestedSubject.send(uuid)
    }

}
