//
//  ViewController+IO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension ViewController {
    func saveCanvas(into tmpFolderURL: URL, with zipFileName: String) {
        createTemporaryFolderWithErrorHandling(tmpFolderURL: tmpFolderURL) { [weak self] tmpFolderURL in
            guard   let self,
                    let currentTexture = canvasView.rootTexture else { return }

            let layerIndex = canvasViewModel.layerManager.index
            let codableLayers = try await canvasViewModel.layerManager.layers.convertToLayerModelCodable(imageFolderURL: tmpFolderURL)
            try canvasViewModel.saveCanvasAsZipFile(rootTexture: currentTexture,
                                                    layerIndex: layerIndex,
                                                    codableLayers: codableLayers,
                                                    tmpFolderURL: tmpFolderURL,
                                                    with: zipFileName)
        }
    }
    func loadCanvas(from zipFilePath: String, into tmpFolderURL: URL) {
        createTemporaryFolderWithErrorHandling(tmpFolderURL: tmpFolderURL) { [weak self] folderURL in
            guard let self else { return }

            if let data = try canvasViewModel.loadCanvasDataV2(from: zipFilePath, into: folderURL) {
                guard let textureSize = data.textureSize,
                      let layers = try data.layers?.compactMap({ $0 }).convertToLayerModel(device: canvasViewModel.device,
                                                                                           textureSize: textureSize,
                                                                                           folderURL: folderURL) else { return }
                try canvasViewModel.applyCanvasDataToCanvasV2(data,
                                                              layers: layers,
                                                              folderURL: folderURL,
                                                              zipFilePath: zipFilePath)

            } else if let data = try canvasViewModel.loadCanvasData(from: zipFilePath,
                                                                    into: folderURL) {
                try canvasViewModel.applyCanvasDataToCanvas(data,
                                                            folderURL: folderURL,
                                                            zipFilePath: zipFilePath)
            }

            initAllComponents()
            canvasViewModel.layerManager.updateNonSelectedTextures()
            canvasView.refreshCanvas()
        }
    }
    private func createTemporaryFolderWithErrorHandling(tmpFolderURL: URL,
                                                        _ tasks: @escaping (URL) async throws -> Void) {
        Task {
            let activityIndicatorView = ActivityIndicatorView(frame: view.frame)
            defer {
                try? FileManager.default.removeItem(atPath: tmpFolderURL.path)
                activityIndicatorView.removeFromSuperview()
            }
            view.addSubview(activityIndicatorView)

            do {
                // Clean up the temporary folder when done
                try FileManager.createNewDirectory(url: tmpFolderURL)

                try await tasks(tmpFolderURL)

                try await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }
}
