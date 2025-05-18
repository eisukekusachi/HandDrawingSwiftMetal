//
//  TextureLayerDocumentsDirectoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import MetalKit
import SwiftUI

/// A repository that manages on-disk textures and in-memory thumbnails
final class TextureLayerDocumentsDirectoryRepository: TextureDocumentsDirectoryRepository, TextureLayerRepository {

    @Published private(set) var thumbnails: [UUID: UIImage?] = [:]

    private let thumbnailUpdateRequestedSubject: PassthroughSubject<UUID, Never> = .init()

    private let device = MTLCreateSystemDefaultDevice()!

    private var cancellables = Set<AnyCancellable>()

    override init(
        directoryName: String,
        textures: Set<UUID> = [],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        super.init(
            directoryName: directoryName,
            textures: textures,
            renderer: renderer
        )
    }

    /// Deletes all files within the directory and clears texture ID data and the thumbnails
    override func removeAll() {
        try? FileManager.clearContents(of: directoryUrl)
        textureIds = []
        thumbnails = [:]
    }

    override func removeTexture(_ uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard let `self` else { return }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }

            textureIds.remove(uuid)
            thumbnails.removeValue(forKey: uuid)

            promise(.success(uuid))
        }
        .eraseToAnyPublisher()
    }

    override func updateAllTextures(uuids: [UUID], textureSize: CGSize, from sourceURL: URL) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let `self` else { return }

            // Delete all files
            self.resetDirectory(&self.directoryUrl)

            do {
                try uuids.forEach { uuid in
                    let textureData = try Data(
                        contentsOf: sourceURL.appendingPathComponent(uuid.uuidString)
                    )

                    if let hexadecimalData = textureData.encodedHexadecimals,
                       let texture = MTLTextureCreator.makeTexture(
                        size: textureSize,
                        colorArray: hexadecimalData,
                        with: self.device
                       ) {
                        try FileOutputManager.saveTextureAsData(
                            bytes: texture.bytes,
                            to: self.directoryUrl.appendingPathComponent(uuid.uuidString)
                        )

                        self.textureIds.insert(uuid)
                        self.setThumbnail(texture: texture, for: uuid)
                    }
                }
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    /// Updates an existing texture for UUID
    override func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<UUID, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let texture
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            do {
                let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

                try FileOutputManager.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )
                self.setThumbnail(texture: texture, for: uuid)

                promise(.success(uuid))
            } catch {
                Logger.standard.warning("Failed to save texture for UUID \(uuid): \(error)")
                promise(.failure(FileOutputError.failedToUpdateTexture))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerDocumentsDirectoryRepository {

    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> {
        thumbnailUpdateRequestedSubject.eraseToAnyPublisher()
    }

    func getThumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let `self` else { return }

            do {
                for textureId in self.textureIds {
                    let url = self.directoryUrl.appendingPathComponent(textureId.uuidString)
                    if FileManager.default.fileExists(atPath: url.path) {
                        let texture: MTLTexture? = try FileInputManager.loadTexture(
                            url: url,
                            textureSize: textureSize,
                            device: self.device
                        )
                        self.setThumbnail(texture: texture, for: textureId)
                    } else {
                        Logger.standard.error("Failed to load texture for \(textureId.uuidString): file not found")
                    }
                }

                promise(.success(()))

            } catch {
                Logger.standard.error("Failed to load texture during thumbnail update: \(error)")
                promise(.failure(FileOutputError.failedToUpdateTexture))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerDocumentsDirectoryRepository {

    private func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        guard let texture else {
            Logger.standard.warning("Failed to create thumbnail for \(uuid)")
            return
        }
        thumbnails[uuid] = texture.makeThumbnail()
        thumbnailUpdateRequestedSubject.send(uuid)
    }

}
