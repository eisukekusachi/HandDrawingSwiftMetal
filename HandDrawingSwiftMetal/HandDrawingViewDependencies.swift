//
//  HandDrawingViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/04.
//

import Foundation
import TextureLayerView

final class HandDrawingViewDependencies {

    let localFileRepository: LocalFileRepositoryProtocol

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    @MainActor
    init(
        localFileRepository: LocalFileRepositoryProtocol = LocalFileRepository(
            workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
        ),
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.localFileRepository = localFileRepository
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
