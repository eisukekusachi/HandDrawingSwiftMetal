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

    let localFileRepository: LocalFileRepositoryProtocol
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    init(
        fileManager: FileManaging = FileManagerWrapper(),
        localFileRepository: LocalFileRepositoryProtocol? = nil,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.localFileRepository = localFileRepository ?? LocalFileRepository(
            workingDirectoryURL: fileManager.temporaryDirectory.appendingPathComponent("TmpFolder"),
            fileManager: fileManager
        )
        self.textureLayersDocumentsRepository =
            textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
