//
//  LocalRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation
import Combine

protocol LocalRepository {

    func loadDataFromDocuments(
        sourceURL: URL,
        canvasViewModel: CanvasViewModel
    ) -> AnyPublisher<Void, Error>

    func saveDataToDocuments(
        data: ExportCanvasData,
        to zipFileURL: URL
    ) -> AnyPublisher<Void, Error>

}
