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
            let activityIndicatorView = ActivityIndicatorView(frame: view.frame)
            defer {
                activityIndicatorView.removeFromSuperview()
            }
            view.addSubview(activityIndicatorView)

            do {
                try exportCanvasDataAsZip(canvas, zipFileName: canvas.zipFileNamePath)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }
    func loadCanvas(zipFilePath: String) {
        Task {
            let activityIndicatorView = ActivityIndicatorView(frame: view.frame)
            defer {
                activityIndicatorView.removeFromSuperview()
            }
            view.addSubview(activityIndicatorView)

            do {
                try loadCanvasDataFromZip(zipFilePath: zipFilePath)
                refreshAllComponents()

                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }

    private func exportCanvasDataAsZip(_ canvas: Canvas, zipFileName: String) throws {

        let folderUrl = URL.documents.appendingPathComponent("tmpFolder")
        let zipFileUrl = URL.documents.appendingPathComponent(zipFileName)

        // Clean up the temporary folder when done
        defer {
            try? FileManager.default.removeItem(atPath: folderUrl.path)
        }
        try FileManager.createNewDirectory(url: folderUrl)

        try canvas.write(to: folderUrl)
        
        try FileOutput.zip(folderURL: folderUrl, zipFileURL: zipFileUrl)
    }

    private func loadCanvasDataFromZip(zipFilePath: String) throws {

        let folderUrl = URL.documents.appendingPathComponent("tmpFolder")
        let zipFileUrl = URL.documents.appendingPathComponent(zipFilePath)
        let jsonUrl = folderUrl.appendingPathComponent(Canvas.jsonFilePath)

        // Clean up the temporary folder when done
        defer {
            try? FileManager.default.removeItem(at: folderUrl)
        }

        // Unzip the contents of the ZIP file
        try FileManager.createNewDirectory(url: folderUrl)

        try FileInput.unzip(srcZipURL: zipFileUrl, to: folderUrl)

        let data: CanvasCodableData = try FileInput.loadJson(url: jsonUrl)
        canvas.load(from: data, projectName: zipFilePath.fileName, folderURL: folderUrl)
    }
}
