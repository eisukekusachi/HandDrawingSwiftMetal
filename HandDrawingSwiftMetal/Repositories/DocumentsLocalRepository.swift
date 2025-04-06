//
//  DocumentsLocalRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import MetalKit
import Combine

enum DocumentsLocalRepositoryError: Error {
    case exportThumbnailError
    case exportLayerDataError
}

final class DocumentsLocalRepository: LocalRepository {

    func saveDataToDocuments(
        renderTexture: MTLTexture,
        textureLayers: TextureLayers,
        drawingTool: CanvasDrawingToolStatus,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        /*
        Future<Void, Error> { promise in
            Task {
                do {
                    try FileManager.createNewDirectory(url: URL.tmpFolderURL)
                    promise(.success(()))
                } catch {
                    promise(.failure(DocumentsLocalRepositoryError.exportLayerDataError))
                }
            }
        }
        .flatMap { _ in
            Publishers.CombineLatest(
                self.exportThumbnail(
                    texture: renderTexture,
                    fileName: URL.thumbnailPath,
                    height: 500,
                    to: URL.tmpFolderURL
                ),
                self.exportLayerData(
                    layers: textureLayers.layers,
                    to: URL.tmpFolderURL
                )
            )
            .eraseToAnyPublisher()
        }
        .compactMap { thumbnailName, layers in
            CanvasEntity.init(
                thumbnailName: thumbnailName,
                textureSize: renderTexture.size,
                layerIndex: textureLayers.index,
                layers: layers,
                drawingTool: drawingTool
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
         */
    }

    func loadDataFromDocuments(
        sourceURL: URL
    ) -> AnyPublisher<CanvasModel, Error> {
        return Just(.init())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        /*
        Future<CanvasModel, Error> { promise in
            Task {
                defer {
                    try? FileManager.default.removeItem(atPath: URL.tmpFolderURL.path)
                }

                do {
                    try FileManager.createNewDirectory(url: URL.tmpFolderURL)
                    try await FileInputManager.unzip(sourceURL, to: URL.tmpFolderURL)

                    let entity = try FileInputManager.getCanvasEntity(
                        fileURL: URL.tmpFolderURL.appendingPathComponent(URL.jsonFileName)
                    )

                    let model = try CanvasModel.init(
                        projectName: sourceURL.fileName,
                        entity: entity,
                        folderURL: URL.tmpFolderURL
                    )

                    promise(.success(model))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
        */
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
                promise(.failure(DocumentsLocalRepositoryError.exportThumbnailError))
            }
        }
        .eraseToAnyPublisher()
    }

    /*
    private func exportLayerData(
        layers: [TextureLayer],
        to url: URL
    ) -> AnyPublisher<[ImageLayerEntity], Error> {
        Future<[ImageLayerEntity], Error> { promise in
            do {
                let layerEntities = try layers.map { layer -> ImageLayerEntity in
                    let textureName = UUID().uuidString

                    try FileOutputManager.saveImage(
                        bytes: layer.texture?.bytes ?? [],
                        to: url.appendingPathComponent(textureName)
                    )

                    return ImageLayerEntity(
                        textureName: textureName,
                        title: layer.title,
                        alpha: layer.alpha,
                        isVisible: layer.isVisible
                    )
                }
                promise(.success(layerEntities))
            } catch {
                promise(.failure(DocumentsLocalRepositoryError.exportLayerDataError))
            }
        }
        .eraseToAnyPublisher()
    }
    */
}
