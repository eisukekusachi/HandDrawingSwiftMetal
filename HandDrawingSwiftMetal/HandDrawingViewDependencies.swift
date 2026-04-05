//
//  HandDrawingViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/04.
//

import Foundation

final class HandDrawingViewDependencies {

    let localFileRepository: LocalFileRepositoryProtocol

    init(
        localFileRepository: LocalFileRepositoryProtocol = LocalFileRepository(
            workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    ) {
        self.localFileRepository = localFileRepository
    }
}
