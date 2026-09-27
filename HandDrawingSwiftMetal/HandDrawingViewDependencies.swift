//
//  HandDrawingViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/04.
//

import Core
import Foundation
import TextureLayerView

@MainActor
final class HandDrawingViewDependencies {

    let fileManager: FileManaging
    let localFileRepository: LocalFileRepositoryProtocol
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    init(
        fileManager: FileManaging? = nil,
        localFileRepository: LocalFileRepositoryProtocol? = nil,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        let fileManager = fileManager ?? FileManagerWrapper()
        self.fileManager = fileManager
        self.localFileRepository = localFileRepository ?? LocalFileRepository(
            workingDirectoryURL: fileManager.temporaryDirectory.appendingPathComponent("TmpFolder"),
            fileManager: fileManager
        )
        self.textureLayersDocumentsRepository =
            textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
