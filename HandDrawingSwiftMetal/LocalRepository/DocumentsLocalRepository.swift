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

    private var cancellables = Set<AnyCancellable>()

    func saveDataToDocuments(
        renderTexture: MTLTexture,
        textureLayers: TextureLayers,
        drawingTool: CanvasDrawingToolStatus,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            Task { [weak self] in
                guard let `self` else { return }

                try FileManager.createNewDirectory(url: URL.tmpFolderURL)

                Publishers.CombineLatest(
                    DocumentsLocalRepository.exportThumbnail(
                        texture: renderTexture,
                        fileName: URL.thumbnailPath,
                        height: 500,
                        to: URL.tmpFolderURL
                    ),
                    DocumentsLocalRepository.exportLayerData(
                        layers: textureLayers.layers,
                        to: URL.tmpFolderURL
                    )
                )
                .compactMap { thumbnailName, layers -> CanvasEntity? in
                    return .init(
                        thumbnailName: thumbnailName,
                        textureSize: renderTexture.size,
                        layerIndex: textureLayers.index,
                        layers: layers,
                        drawingTool: drawingTool
                    )
                }
                .tryMap { result -> Void in
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
                .sink { completion in

                    try? FileManager.default.removeItem(atPath: URL.tmpFolderURL.path)

                    switch completion {
                    case .finished: promise(.success(()))
                    case .failure(let error): promise(.failure(error))
                    }
                } receiveValue: { _  in }
                .store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }

    func loadDataFromDocuments(
        sourceURL: URL
    ) -> AnyPublisher<CanvasModel, Error> {
        Future<CanvasModel, Error> { promise in
            Task {
                do {
                    try FileManager.createNewDirectory(url: URL.tmpFolderURL)
                    try await FileInputManager.unzip(sourceURL, to: URL.tmpFolderURL)
                } catch {
                    promise(.failure(error))
                }

                defer {
                    try? FileManager.default.removeItem(atPath: URL.tmpFolderURL.path)
                }

                let entity = try FileInputManager.getCanvasEntity(
                    fileURL: URL.tmpFolderURL.appendingPathComponent(URL.jsonFileName)
                )

                promise(.success(
                    .init(
                        projectName: sourceURL.fileName,
                        device: MTLCreateSystemDefaultDevice()!,
                        entity: entity,
                        folderURL: URL.tmpFolderURL
                    )
                ))
            }
        }
        .eraseToAnyPublisher()
    }

}

extension DocumentsLocalRepository {
    static func exportThumbnail(
        texture: MTLTexture,
        fileName: String,
        height: CGFloat,
        to url: URL
    ) -> AnyPublisher<String, DocumentsLocalRepositoryError> {
        let thumbnail = texture.uiImage?.resizeWithAspectRatio(height: height, scale: 1.0)
        let publisher = Future<String, DocumentsLocalRepositoryError> { promise in
            do {
                try FileOutputManager.saveImage(
                    image: thumbnail,
                    to: url.appendingPathComponent(fileName)
                )
                promise(.success(fileName))
            } catch {
                promise(.failure(.exportThumbnailError))
            }
        }
        return publisher.eraseToAnyPublisher()
    }

    static func exportLayerData(
        layers: [TextureLayer],
        to url: URL
    ) -> AnyPublisher<[ImageLayerEntity], DocumentsLocalRepositoryError> {
        let publisher = Future<[ImageLayerEntity], DocumentsLocalRepositoryError> { promise in
            do {
                var layerEntities: [ImageLayerEntity] = []

                for layer in layers {
                    let textureName = UUID().uuidString

                    try FileOutputManager.saveImage(
                        bytes: layer.texture?.bytes ?? [],
                        to: url.appendingPathComponent(textureName)
                    )
                    layerEntities.append(
                        .init(
                            textureName: textureName,
                            title: layer.title,
                            alpha: layer.alpha,
                            isVisible: layer.isVisible
                        )
                    )
                }
                promise(.success(layerEntities))
            } catch {
                promise(.failure(.exportLayerDataError))
            }
        }
        return publisher.eraseToAnyPublisher()
    }

}
