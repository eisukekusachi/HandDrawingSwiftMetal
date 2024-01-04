//
//  ViewController+IO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension ViewController {
    func saveCanvas(into tmpFolderURL: URL, with zipFileName: String) {
        createTemporaryFolder(tmpFolderURL: tmpFolderURL) { [weak self] folderURL in
            guard let currentTexture = self?.canvasView.rootTexture else { return }

            try self?.canvasViewModel.saveCanvasAsZipFile(rootTexture: currentTexture,
                                                          into: folderURL,
                                                          with: zipFileName)
        }
    }
    func loadCanvas(from zipFilePath: String, into tmpFolderURL: URL) {
        createTemporaryFolder(tmpFolderURL: tmpFolderURL) { [weak self] folderURL in
            if let data = try self?.canvasViewModel.loadCanvasDataV2(from: zipFilePath,
                                                                     into: folderURL) {
                try self?.canvasViewModel.applyCanvasDataToCanvasV2(data,
                                                                    folderURL: folderURL,
                                                                    zipFilePath: zipFilePath)

            } else if let data = try self?.canvasViewModel.loadCanvasData(from: zipFilePath,
                                                                          into: folderURL) {
                try self?.canvasViewModel.applyCanvasDataToCanvas(data,
                                                                  folderURL: folderURL,
                                                                  zipFilePath: zipFilePath)
            }

            self?.initAllComponents()
            self?.canvasViewModel.layerManager.updateNonSelectedTextures()
            self?.canvasView.refreshCanvas()
        }
    }
    private func createTemporaryFolder(tmpFolderURL: URL,
                                       _ tasks: @escaping (URL) throws -> Void) {
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

                try tasks(tmpFolderURL)

                try await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }
}
