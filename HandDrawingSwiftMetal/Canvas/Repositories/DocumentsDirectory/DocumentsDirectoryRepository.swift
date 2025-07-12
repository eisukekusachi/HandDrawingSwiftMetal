//
//  DocumentsDirectoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import MetalKit

final class DocumentsDirectoryRepository {

    private static let thumbnailName: String = "thumbnail.png"

    private var saveDataTask: Task<Void, Error>?
    private var loadDataTask: Task<Void, Error>?

    private let workingDirectory = URL.tmpFolderURL

    deinit {
        saveDataTask?.cancel()
        loadDataTask?.cancel()
    }
    func saveData(
        renderTexture: MTLTexture,
        canvasState: CanvasState,
        textureRepository: any TextureRepository,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error> {

        let workingDirectory = self.workingDirectory

        return Future<URL, Error> { [weak self] promise in
            self?.saveDataTask?.cancel()
            self?.saveDataTask = Task {
                do {
                    try FileManager.createNewDirectory(url: workingDirectory)
                    promise(.success(workingDirectory))
                } catch {
                    promise(.failure(DocumentsLocalRepositoryError.exportLayerData))
                }
            }
        }
        .flatMap { url in
            Publishers.CombineLatest(
                self.exportThumbnail(
                    texture: renderTexture,
                    fileName: DocumentsDirectoryRepository.thumbnailName,
                    height: 500,
                    to: url
                ),
                self.exportTextures(
                    textureIds: canvasState.layers.map { $0.id },
                    textureSize: canvasState.textureSize,
                    textureRepository: textureRepository,
                    to: url
                )
            )
            .eraseToAnyPublisher()
        }
        .compactMap { thumbnailName, _ in
            CanvasEntity.init(
                thumbnailName: thumbnailName,
                textureSize: renderTexture.size,
                layerIndex: canvasState.selectedIndex ?? 0,
                layers: canvasState.layers.map { .init(from: $0) },
                canvasState: canvasState
            )
        }
        .tryMap { result in
            try FileOutput.saveJson(
                result,
                to: workingDirectory.appendingPathComponent(URL.jsonFileName)
            )
        }
        .tryMap { result in
            try FileOutput.zip(
                workingDirectory,
                to: zipFileURL
            )
        }
        .handleEvents(receiveCompletion: { [weak self] _ in
            self?.removeWorkingDirectory()
        })
        .eraseToAnyPublisher()
    }

    func loadData(
        from sourceURL: URL,
        textureRepository: any TextureRepository
    ) -> AnyPublisher<CanvasConfiguration, Error> {

        let workingDirectory = self.workingDirectory

        return Future<CanvasEntity, Error> { [weak self] promise in
            self?.loadDataTask?.cancel()
            self?.loadDataTask = Task {
                do {
                    try FileManager.createNewDirectory(url: workingDirectory)
                    try await FileInput.unzip(sourceURL, to: workingDirectory)

                    let entity = try FileInput.getCanvasEntity(
                        fileURL: workingDirectory.appendingPathComponent(URL.jsonFileName)
                    )
                    promise(.success(entity))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .flatMap { entity -> AnyPublisher<CanvasConfiguration, Never> in
            Just(
                .init(
                    projectName: sourceURL.fileName,
                    entity: entity
                )
            )
            .eraseToAnyPublisher()
        }
        .flatMap { configuration -> AnyPublisher<CanvasConfiguration, Error> in
            guard
                let textureSize = configuration.textureSize,
                Int(textureSize.width) > MTLRenderer.threadGroupLength && Int(textureSize.height) > MTLRenderer.threadGroupLength
            else {
                Logger.standard.error("Texture size is below the minimum: \(configuration.textureSize?.width ?? 0) \(configuration.textureSize?.height ?? 0)")
                return Fail(error: DocumentsLocalRepositoryError.invalidTextureSize)
                    .eraseToAnyPublisher()
            }
            return textureRepository.resetStorage(
                configuration: configuration,
                sourceFolderURL: workingDirectory
            )
            .eraseToAnyPublisher()
        }
        .handleEvents(receiveCompletion: { [weak self] _ in
            self?.removeWorkingDirectory()
        })
        .eraseToAnyPublisher()
    }

    func removeWorkingDirectory() {
        try? FileManager.default.removeItem(at: workingDirectory)
    }
}

extension DocumentsDirectoryRepository {
    private func exportThumbnail(
        texture: MTLTexture,
        fileName: String,
        height: CGFloat,
        to url: URL
    ) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            do {
                try FileOutput.saveImage(
                    image: texture.uiImage?.resizeWithAspectRatio(height: height, scale: 1.0),
                    to: url.appendingPathComponent(fileName)
                )
                promise(.success(fileName))
            } catch {
                Logger.standard.error("Failed to export thumbnail: \(error)")
                promise(.failure(DocumentsLocalRepositoryError.exportThumbnail))
            }
        }
        .eraseToAnyPublisher()
    }

    private func exportTextures(
        textureIds: [UUID],
        textureSize: CGSize,
        textureRepository: any TextureRepository,
        to url: URL
    ) -> AnyPublisher<Void, Error> {
        textureRepository.copyTextures(
            uuids: textureIds
        )
            .tryMap { results in
                guard results.count == textureIds.count else {
                    Logger.standard.error("Failed to export textures: mismatch between texture IDs and loaded textures.")
                    throw DocumentsLocalRepositoryError.exportLayerData
                }
                // Convert entities to a dictionary for easy lookup
                let textureDict = Dictionary(uniqueKeysWithValues: results.map { ($0.uuid, $0.texture) })

                try textureIds.forEach { id in
                    guard let texture = textureDict[id].flatMap({ $0 }) else {
                        throw DocumentsLocalRepositoryError.exportLayerData
                    }
                    let fileURL = url.appendingPathComponent(id.uuidString)
                    try FileOutput.saveTextureAsData(
                        bytes: texture.bytes,
                        to: fileURL
                    )
                }

                return ()
            }
            .mapError { _ in DocumentsLocalRepositoryError.exportLayerData }
            .eraseToAnyPublisher()
    }
}

enum DocumentsLocalRepositoryError: Error {
    case exportThumbnail
    case exportLayerData
    case invalidTextureSize
}
