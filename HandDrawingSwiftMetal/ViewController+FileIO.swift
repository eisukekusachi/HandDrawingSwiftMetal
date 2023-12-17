//
//  ViewController+FileIO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension ViewController {
    func saveCanvas() {
        Task {
            let folderURL = CanvasViewModel.folderURL
            let activityIndicatorView = ActivityIndicatorView(frame: view.frame)
            defer {
                try? FileManager.default.removeItem(atPath: CanvasViewModel.folderURL.path)
                activityIndicatorView.removeFromSuperview()
            }
            view.addSubview(activityIndicatorView)

            guard let currentTexture = canvasView.currentTexture  else { return }

            do {
                // Clean up the temporary folder when done
                try FileManager.createNewDirectory(url: CanvasViewModel.folderURL)

                try canvasViewModel.saveCanvasAsZipFile(texture: currentTexture,
                                                        textureName: UUID().uuidString,
                                                        folderURL: folderURL,
                                                        zipFileName: canvasViewModel.zipFileNamePath)

                try await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }
    func loadCanvas(zipFilePath: String) {
        Task {
            let folderURL = CanvasViewModel.folderURL
            let activityIndicatorView = ActivityIndicatorView(frame: view.frame)
            defer {
                try? FileManager.default.removeItem(atPath: folderURL.path)
                activityIndicatorView.removeFromSuperview()
            }
            view.addSubview(activityIndicatorView)

            do {
                // Clean up the temporary folder when done
                try FileManager.createNewDirectory(url: folderURL)

                let data = try canvasViewModel.loadCanvas(folderURL: folderURL, zipFilePath: zipFilePath)

                try canvasViewModel.applyDataToCanvas(data, folderURL: folderURL, zipFilePath: zipFilePath)
                initAllComponents()
                canvasView.refreshCanvas()

                try await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }
}
