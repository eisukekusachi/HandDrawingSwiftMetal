//
//  DocumentsLocalSingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/27.
//

import Combine
import Foundation
import MetalKit

final class DocumentsLocalSingletonRepository: LocalRepository {

    static let shared = DocumentsLocalRepository()

    private let repository: any LocalRepository

    private init(repository: any LocalRepository = DocumentsLocalRepository()) {
        self.repository = repository
    }

    func loadDataFromDocuments(
        sourceURL: URL,
        textureRepository: TextureRepository
    ) -> AnyPublisher<CanvasConfiguration, any Error> {
        repository.loadDataFromDocuments(
            sourceURL: sourceURL,
            textureRepository: textureRepository
        )
    }

    func saveDataToDocuments(
        renderTexture: any MTLTexture,
        canvasState: CanvasState,
        textureRepository: any TextureRepository,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, any Error> {
        repository.saveDataToDocuments(
            renderTexture: renderTexture,
            canvasState: canvasState,
            textureRepository: textureRepository,
            to: zipFileURL
        )
    }

}
