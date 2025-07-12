//
//  LocalFileRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import MetalKit

final class LocalFileRepository {

    static let workingDirectory = URL.applicationSupport.appendingPathComponent("TmpFolder")

    static let thumbnailName: String = "thumbnail.png"

    static let jsonFileName: String = "data"

    static let thumbnailLength: CGFloat = 500

    static func fileURL(projectName: String, suffix: String) -> URL {
        URL.documents.appendingPathComponent(projectName + "." + suffix)
    }
}

extension LocalFileRepository {

    func zipWorkingDirectory(
        to zipFileURL: URL
    ) throws {
        try FileOutput.zip(
            LocalFileRepository.workingDirectory,
            to: zipFileURL
        )
    }

    func unzipToWorkingDirectory(
        from zipFileURL: URL
    ) -> AnyPublisher<URL, Error> {
        let workingDirectory = LocalFileRepository.workingDirectory

        return Future<URL, Error> { promise in
            Task {
                do {
                    try await FileInput.unzip(zipFileURL, to: workingDirectory)
                    promise(
                        .success(workingDirectory)
                    )

                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

extension LocalFileRepository {

    func createWorkingDirectory() throws {
        do {
            try FileManager.createNewDirectory(url: LocalFileRepository.workingDirectory)
        } catch {
            throw DocumentsDirectoryRepositoryError.operationError(
                "createWorkingDirectory()"
            )
        }
    }

    func removeWorkingDirectory() {
        // Do nothing if directory deletion fails
        try? FileManager.default.removeItem(at: LocalFileRepository.workingDirectory)
    }
}

extension LocalFileRepository {

    func saveToWorkingDirectory<T: LocalFileConvertible>(
        item: T,
        fileName: String
    ) -> AnyPublisher<URL, Error> {
        let fileURL = LocalFileRepository.workingDirectory.appendingPathComponent(fileName)

        return Future<URL, Error> { promise in
            do {
                try item.write(to: fileURL)
                promise(.success(fileURL))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func saveTexturesToWorkingDirectory(
        textureRepository: TextureRepository,
        textureIds: [UUID]
    ) -> AnyPublisher<[URL], Error> {
        let workingDirectory = LocalFileRepository.workingDirectory

        return textureRepository.copyTextures(
            uuids: textureIds
        )
        .tryMap { results in
            guard results.count == textureIds.count else {
                Logger.standard.error("Failed to export textures: mismatch between texture IDs and loaded textures.")
                throw DocumentsDirectoryRepositoryError.operationError("saveTexturesToWorkingDirectory(textureRepository:, textureIds:)")
            }
            // Convert entities to a dictionary for easy lookup
            let textureDictionary = IdentifiedTexture.dictionary(from: Set(results))

            var urls: [URL] = []

            try textureIds.forEach { id in
                guard let texture = textureDictionary[id] else {
                    throw DocumentsDirectoryRepositoryError.operationError("saveTexturesToWorkingDirectory(textureRepository:, textureIds:)")
                }
                let fileURL = workingDirectory.appendingPathComponent(id.uuidString)
                try FileOutput.saveTextureAsData(
                    bytes: texture.bytes,
                    to: fileURL
                )
                urls.append(fileURL)
            }

            return urls
        }
        .mapError { _ in DocumentsDirectoryRepositoryError.operationError("saveTexturesToWorkingDirectory(textureRepository:, textureIds:)") }
        .eraseToAnyPublisher()
    }
}

enum DocumentsDirectoryRepositoryError: Error {
    case error(Error)
    case operationError(String)
    case invalidValue(String)
}
