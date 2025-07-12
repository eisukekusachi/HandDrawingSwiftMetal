//
//  LocalFileRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import Foundation

final class LocalFileRepository {

    let workingDirectory = URL.applicationSupport.appendingPathComponent("TmpFolder")

    static func fileURL(projectName: String, suffix: String) -> URL {
        URL.documents.appendingPathComponent(projectName + "." + suffix)
    }
}

extension LocalFileRepository {

    func zipWorkingDirectory(
        to zipFileURL: URL
    ) throws {
        try FileOutput.zip(
            workingDirectory,
            to: zipFileURL
        )
    }

    func unzipToWorkingDirectory(
        from zipFileURL: URL
    ) -> AnyPublisher<URL, Error> {
        let workingDirectory = workingDirectory

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
            try FileManager.createNewDirectory(url: workingDirectory)
        } catch {
            throw DocumentsDirectoryRepositoryError.operationError(
                "createWorkingDirectory()"
            )
        }
    }

    func removeWorkingDirectory() {
        // Do nothing if directory deletion fails
        try? FileManager.default.removeItem(at: workingDirectory)
    }
}

extension LocalFileRepository {

    func saveToWorkingDirectory<T: LocalFileConvertible>(
        namedItem: LocalFileNamedItem<T>
    ) -> AnyPublisher<URL, Error> {
        let fileURL = workingDirectory.appendingPathComponent(namedItem.name)

        return Future<URL, Error> { promise in
            do {
                try namedItem.item.write(to: fileURL)
                promise(.success(fileURL))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    func saveAllToWorkingDirectory<T: LocalFileConvertible>(
        namedItems: [LocalFileNamedItem<T>]
    ) -> AnyPublisher<[URL], Error> {
        Publishers.MergeMany(
            namedItems.map { namedItem in
                saveToWorkingDirectory(namedItem: namedItem)
            }
        )
        .collect()
        .eraseToAnyPublisher()
    }
}

enum DocumentsDirectoryRepositoryError: Error {
    case error(Error)
    case operationError(String)
    case invalidValue(String)
}
