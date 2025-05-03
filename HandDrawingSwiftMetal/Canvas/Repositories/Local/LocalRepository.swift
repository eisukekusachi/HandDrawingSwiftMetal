//
//  LocalRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import MetalKit

protocol LocalRepository {

    func loadDataFromDocuments(
        sourceURL: URL,
        textureRepository: any TextureRepository
    ) -> AnyPublisher<CanvasConfiguration, Error>

    func saveDataToDocuments(
        renderTexture: MTLTexture,
        canvasState: CanvasState,
        textureRepository: any TextureRepository,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error>

}
