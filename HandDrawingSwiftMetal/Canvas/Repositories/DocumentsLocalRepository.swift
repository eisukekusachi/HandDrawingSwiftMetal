//
//  DocumentsLocalRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import MetalKit

final class DocumentsLocalRepository: LocalRepository {

    private static let thumbnailName: String = "thumbnail.png"

    private var saveDataTask: Task<Void, Error>?
    private var loadDataTask: Task<Void, Error>?

    deinit {
        saveDataTask?.cancel()
        loadDataTask?.cancel()
    }
    func saveDataToDocuments(
        renderTexture: MTLTexture,
        canvasState: CanvasState,
        textureLayers: TextureLayers,
        textureRepository: any TextureRepository,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error> {
        Future<URL, Error> { [weak self] promise in
            self?.saveDataTask?.cancel()
            self?.saveDataTask = Task {
                do {
                    try FileManager.createNewDirectory(url: URL.tmpFolderURL)
                    promise(.success(URL.tmpFolderURL))
                } catch {
                    promise(.failure(DocumentsLocalRepositoryError.exportLayerData))
                }
            }
        }
        .flatMap { url in
            Publishers.CombineLatest(
                self.exportThumbnail(
                    texture: renderTexture,
                    fileName: DocumentsLocalRepository.thumbnailName,
                    height: 500,
                    to: url
                ),
                self.exportTextures(
                    textureIds: canvasState.layers.map { $0.id },
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
            try FileOutputManager.saveJson(
                result,
                to: URL.tmpFolderURL.appendingPathComponent(URL.jsonFileName)
            )
        }
        .tryMap { result in
            try FileOutputManager.zip(
                URL.tmpFolderURL,
                to: zipFileURL
            )
        }
        .handleEvents(receiveCompletion: { _ in
            try? FileManager.default.removeItem(at: URL.tmpFolderURL)
        })
        .eraseToAnyPublisher()
    }

    func loadDataFromDocuments(
        sourceURL: URL,
        textureRepository: any TextureRepository
    ) -> AnyPublisher<CanvasModel, Error> {
        Future<CanvasEntity, Error> { [weak self] promise in
            self?.loadDataTask?.cancel()
            self?.loadDataTask = Task {
                do {
                    try FileManager.createNewDirectory(url: URL.tmpFolderURL)
                    try await FileInputManager.unzip(sourceURL, to: URL.tmpFolderURL)

                    let entity = try FileInputManager.getCanvasEntity(
                        fileURL: URL.tmpFolderURL.appendingPathComponent(URL.jsonFileName)
                    )
                    promise(.success(entity))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .flatMap { entity -> AnyPublisher<CanvasModel, Never> in
            Just(
                CanvasModel(
                    projectName: sourceURL.fileName,
                    entity: entity
                )
            )
            .eraseToAnyPublisher()
        }
        .flatMap { model -> AnyPublisher<CanvasModel, Error> in
            guard let textureSize = model.textureSize, textureSize > MTLRenderer.minimumTextureSize else {
                return Fail(error: DocumentsLocalRepositoryError.invalidTextureSize)
                    .eraseToAnyPublisher()
            }
            return textureRepository.initTextures(
                layers: model.layers,
                textureSize: textureSize,
                folderURL: URL.tmpFolderURL
            )
            .map { _ in model }
            .eraseToAnyPublisher()
        }
        .handleEvents(receiveCompletion: { _ in
            try? FileManager.default.removeItem(at: URL.tmpFolderURL)
        })
        .eraseToAnyPublisher()
    }

}

extension DocumentsLocalRepository {
    private func exportThumbnail(
        texture: MTLTexture,
        fileName: String,
        height: CGFloat,
        to url: URL
    ) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            do {
                try FileOutputManager.saveImage(
                    image: texture.uiImage?.resizeWithAspectRatio(height: height, scale: 1.0),
                    to: url.appendingPathComponent(fileName)
                )
                promise(.success(fileName))
            } catch {
                promise(.failure(DocumentsLocalRepositoryError.exportThumbnail))
            }
        }
        .eraseToAnyPublisher()
    }

    private func exportTextures(
        textureIds: [UUID],
        textureRepository: any TextureRepository,
        to url: URL
    ) -> AnyPublisher<Void, Error> {
        textureRepository.loadTextures(textureIds)
            .tryMap { textureDict in
                guard textureDict.count == textureIds.count else {
                    throw DocumentsLocalRepositoryError.exportLayerData
                }

                try textureIds.forEach { id in
                    guard let texture = textureDict[id].flatMap({ $0 }) else {
                        throw DocumentsLocalRepositoryError.exportLayerData
                    }
                    let fileURL = url.appendingPathComponent(id.uuidString)
                    try FileOutputManager.saveTextureAsData(
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
