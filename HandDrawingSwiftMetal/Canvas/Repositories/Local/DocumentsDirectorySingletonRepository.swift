//
//  DocumentsDirectorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/27.
//

import Foundation

final class DocumentsDirectorySingletonRepository {

    static let shared = DocumentsDirectoryRepository()

    private let repository: DocumentsDirectoryRepository

    private init(repository: DocumentsDirectoryRepository = .init()) {
        self.repository = repository
    }
}
