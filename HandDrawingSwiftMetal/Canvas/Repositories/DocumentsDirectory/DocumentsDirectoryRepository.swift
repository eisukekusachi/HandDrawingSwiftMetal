//
//  DocumentsDirectoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import MetalKit

final class DocumentsDirectoryRepository {

    static let thumbnailName: String = "thumbnail.png"
    static let thumbnailLength: CGFloat = 500

    static let workingDirectory = URL.tmpFolderURL

    private var saveDataTask: Task<Void, Error>?
    private var loadDataTask: Task<Void, Error>?

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

        let workingDirectory = DocumentsDirectoryRepository.workingDirectory

        return Result {
            try createWorkingDirectory()
        }
        .publisher
        .flatMap { _ in
            Publishers.CombineLatest(
                self.exportThumbnail(
                    texture: renderTexture,
                    fileName: DocumentsDirectoryRepository.thumbnailName,
                    height: DocumentsDirectoryRepository.thumbnailLength,
                    to: workingDirectory
                ),
                self.exportTextures(
                    textureIds: canvasState.layers.map { $0.id },
                    textureSize: canvasState.textureSize,
                    textureRepository: textureRepository,
                    to: workingDirectory
                )
            )
            .eraseToAnyPublisher()
        }
        .compactMap { thumbnailName, _ in
            CanvasEntity.init(
                thumbnailName: thumbnailName,
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

    func unzipToWorkingDirectory(
        zipFileURL url: URL
    ) -> AnyPublisher<URL, Error> {
        let workingDirectory = DocumentsDirectoryRepository.workingDirectory

        return Future<URL, Error> { [weak self] promise in
            self?.loadDataTask?.cancel()
            self?.loadDataTask = Task {
                do {
                    try FileManager.createNewDirectory(url: workingDirectory)
                    try await FileInput.unzip(url, to: workingDirectory)

                    promise(.success(workingDirectory))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func createWorkingDirectory() throws {
        do {
            try FileManager.createNewDirectory(url: DocumentsDirectoryRepository.workingDirectory)
        } catch {
            throw DocumentsDirectoryRepositoryError.operationError(
                "createWorkingDirectory()"
            )
        }
    }

    func removeWorkingDirectory() {
        // Do nothing if directory deletion fails
        try? FileManager.default.removeItem(at: DocumentsDirectoryRepository.workingDirectory)
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
                promise(.failure(DocumentsDirectoryRepositoryError.error(error)))
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
                    throw DocumentsDirectoryRepositoryError.operationError("exportTextures(textureIds:, textureSize:, textureRepository:, to:)")
                }
                // Convert entities to a dictionary for easy lookup
                let textureDict = Dictionary(uniqueKeysWithValues: results.map { ($0.uuid, $0.texture) })

                try textureIds.forEach { id in
                    guard let texture = textureDict[id].flatMap({ $0 }) else {
                        throw DocumentsDirectoryRepositoryError.operationError("exportTextures(textureIds:, textureSize:, textureRepository:, to:)")
                    }
                    let fileURL = url.appendingPathComponent(id.uuidString)
                    try FileOutput.saveTextureAsData(
                        bytes: texture.bytes,
                        to: fileURL
                    )
                }

                return ()
            }
            .mapError { _ in DocumentsDirectoryRepositoryError.operationError("exportTextures(textureIds:, textureSize:, textureRepository:, to:)") }
            .eraseToAnyPublisher()
    }
}

enum DocumentsDirectoryRepositoryError: Error {
    case error(Error)
    case operationError(String)
    case invalidValue(String)
}
