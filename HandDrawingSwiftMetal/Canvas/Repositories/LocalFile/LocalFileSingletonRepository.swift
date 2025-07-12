//
//  LocalFileSingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/27.
//

import Foundation

final class LocalFileSingletonRepository {

    static let shared = LocalFileRepository()

    private let repository: LocalFileRepository

    private init(repository: LocalFileRepository = .init()) {
        self.repository = repository
    }
}
