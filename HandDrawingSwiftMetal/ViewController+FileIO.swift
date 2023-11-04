//
//  ViewController+FileIO.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension ViewController {
    func saveCanvasData(_ canvas: Canvas, zipFileName: String) throws {

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
}
