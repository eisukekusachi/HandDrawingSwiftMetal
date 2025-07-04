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

    let objectWillChangeSubject: PassthroughSubject<Void, Never> = .init()

    private(set) var thumbnails: [UUID: UIImage?] = [:]

    private var cancellables = Set<AnyCancellable>()

    override init(
        storageDirectoryURL: URL,
        directoryName: String,
        textures: Set<UUID> = [],
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        super.init(
            storageDirectoryURL: storageDirectoryURL,
            directoryName: directoryName,
            textures: textures,
            renderer: renderer
        )
    }

    override func resetStorage(configuration: CanvasConfiguration, sourceFolderURL: URL) -> AnyPublisher<CanvasConfiguration, Error> {
        Future<CanvasConfiguration, Error> { [weak self] promise in
            guard
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
                var tmpTextureIds: Set<UUID> = []
                var tmpThumbnails: [UUID: UIImage?] = [:]

                try configuration.layers.forEach { layer in
                    let textureData = try Data(
                        contentsOf: sourceFolderURL.appendingPathComponent(layer.id.uuidString)
                    )
                    guard
                        let textureSize = configuration.textureSize,
                        let hexadecimalData = textureData.encodedHexadecimals,
                        let newTexture = MTLTextureCreator.makeTexture(
                            size: textureSize,
                            colorArray: hexadecimalData,
                            with: device
                        )
                    else {
                        throw TextureRepositoryError.failedToUnwrap
                    }

                    tmpTextureIds.insert(layer.id)
                    tmpThumbnails[layer.id] = newTexture.makeThumbnail()
                }

                // Delete all files
                self.resetDirectory(&self.directoryUrl)

                // Move all files
                try configuration.layers.forEach { layer in
                    try FileManager.default.moveItem(
                        at: sourceFolderURL.appendingPathComponent(layer.id.uuidString),
                        to: self.directoryUrl.appendingPathComponent(layer.id.uuidString)
                    )
                }

                self.textureIds = tmpTextureIds
                self.thumbnails = tmpThumbnails

                // Set the texture size after the initialization of this repository is completed
                self.setTextureSize(textureSize)

                promise(.success(configuration))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    override func addTexture(_ texture: MTLTexture?, newTextureUUID uuid: UUID) -> AnyPublisher<IdentifiedTexture, any Error> {
        Future { [weak self] promise in
            guard let `self`, let texture else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            guard !FileManager.default.fileExists(atPath: fileURL.path) else {
                promise(.failure(TextureRepositoryError.fileAlreadyExists))
                return
            }

            do {
                try FileOutputManager.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )
                self.setThumbnail(texture: texture, for: uuid)

                promise(
                    .success(
                        .init(uuid: uuid, texture: texture)
                    )
                )

            } catch {
                promise(.failure(FileOutputError.failedToUpdateTexture(error)))
            }
        }
        .eraseToAnyPublisher()
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

    /// Updates an existing texture for UUID
    override func updateTexture(texture: MTLTexture?, for uuid: UUID) -> AnyPublisher<IdentifiedTexture, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let texture,
                let device = MTLCreateSystemDefaultDevice()
            else {
                promise(.failure(TextureRepositoryError.failedToUnwrap))
                return
            }

            let fileURL = self.directoryUrl.appendingPathComponent(uuid.uuidString)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                promise(.failure(TextureRepositoryError.fileNotFound(fileURL.path)))
                return
            }

            guard let newTexture = MTLTextureCreator.duplicateTexture(
                texture: texture,
                with: device
            ) else {
                promise(.failure(TextureDocumentsDirectoryRepositoryError.failedToCreateNewTexture))
                return
            }

            do {
                try FileOutputManager.saveTextureAsData(
                    bytes: newTexture.bytes,
                    to: fileURL
                )
                self.setThumbnail(texture: texture, for: uuid)

                promise(.success(
                    .init(uuid: uuid, texture: newTexture)
                ))
            } catch {
                promise(.failure(FileOutputError.failedToUpdateTexture(error)))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerDocumentsDirectoryRepository {

    func thumbnail(_ uuid: UUID) -> UIImage? {
        thumbnails[uuid]?.flatMap { $0 }
    }

    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard
                let `self`,
                let device = MTLCreateSystemDefaultDevice()
            else { return }

            do {
                for textureId in self.textureIds {
                    let url = self.directoryUrl.appendingPathComponent(textureId.uuidString)
                    if FileManager.default.fileExists(atPath: url.path) {
                        let texture: MTLTexture? = try FileInputManager.loadTexture(
                            url: url,
                            textureSize: textureSize,
                            device: device
                        )
                        self.setThumbnail(texture: texture, for: textureId)
                    } else {
                        Logger.standard.error("Failed to load texture for \(textureId.uuidString): file not found")
                    }
                }

                promise(.success(()))

            } catch {
                promise(.failure(FileOutputError.failedToUpdateTexture(error)))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension TextureLayerDocumentsDirectoryRepository {

    private func setThumbnail(texture: MTLTexture?, for uuid: UUID) {
        guard let texture else {
            Logger.standard.warning("Failed to unwrap texture for \(uuid)")
            return
        }
        thumbnails[uuid] = texture.makeThumbnail()
        objectWillChangeSubject.send(())
    }

}
