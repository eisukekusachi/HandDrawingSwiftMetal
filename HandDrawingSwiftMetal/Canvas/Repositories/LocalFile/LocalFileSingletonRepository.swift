//
//  LocalFileSingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/27.
//

import Foundation

final class LocalFileSingletonRepository {

    static let shared = LocalFileSingletonRepository()

    let repository: LocalFileRepository

    private init() {
        self.repository = LocalFileRepository(
            workingDirectoryURL: URL.applicationSupport.appendingPathComponent("TmpFolder")
        )
    }
}
