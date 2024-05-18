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
        data: ExportCanvasData,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            Task { [weak self] in
                guard let `self` else { return }

                try FileManager.createNewDirectory(url: URL.tmpFolderURL)

                Publishers.CombineLatest(
                    DocumentsLocalRepository.exportThumbnail(
                        texture: data.canvasTexture,
                        fileName: URL.thumbnailPath,
                        height: 500,
                        to: URL.tmpFolderURL
                    ),
                    DocumentsLocalRepository.exportLayerData(
                        layers: data.layerManager.layers,
                        to: URL.tmpFolderURL
                    )
                )
                .compactMap { thumbnailName, layers -> CanvasEntity? in
                    return .init(
                        thumbnailName: thumbnailName,
                        textureSize: data.layerManager.textureSize,
                        layerIndex: data.layerManager.index,
                        layers: layers,
                        drawingTool: data.drawingTool
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
        sourceURL: URL,
        canvasViewModel: CanvasViewModel
    ) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            Task {
                do {
                    try FileManager.createNewDirectory(url: URL.tmpFolderURL)
                    try await FileInputManager.unzip(sourceURL, to: URL.tmpFolderURL)
                } catch {
                    promise(.failure(error))
                }

                DispatchQueue.main.async {
                    defer {
                        try? FileManager.default.removeItem(atPath: URL.tmpFolderURL.path)
                    }

                    do {
                        let data = try FileInputManager.getCanvasEntity(
                            fileURL: URL.tmpFolderURL.appendingPathComponent(URL.jsonFileName)
                        )
                        try canvasViewModel.applyCanvasDataToCanvas(
                            data: data,
                            fileName: sourceURL.fileName,
                            folderURL: URL.tmpFolderURL
                        )

                        canvasViewModel.layerUndoManager.clear()
                        canvasViewModel.refreshCanvasWithMergingAllLayers()
                        promise(.success(()))

                    } catch {
                        promise(.failure(error))
                    }
                }
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
        let thumbnail = texture.uiImage?.resize(height: height, scale: 1.0)
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
        layers: [ImageLayerEntity],
        to url: URL
    ) -> AnyPublisher<[LayerEntityForExporting], DocumentsLocalRepositoryError> {
        let publisher = Future<[LayerEntityForExporting], DocumentsLocalRepositoryError> { promise in
            do {
                var processedLayers: [LayerEntityForExporting] = []

                for layer in layers {
                    let textureName = UUID().uuidString

                    try FileOutputManager.saveImage(
                        bytes: layer.texture.bytes,
                        to: url.appendingPathComponent(textureName)
                    )
                    processedLayers.append(
                        .init(
                            textureName: textureName,
                            title: layer.title,
                            alpha: layer.alpha,
                            isVisible: layer.isVisible
                        )
                    )
                }
                promise(.success(processedLayers))
            } catch {
                promise(.failure(.exportLayerDataError))
            }
        }
        return publisher.eraseToAnyPublisher()
    }

}
