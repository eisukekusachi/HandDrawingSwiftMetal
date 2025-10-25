//
//  FileInput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/10/25.
//

import UIKit
import ZIPFoundation

enum FileInput {

    static func loadJson<T: Codable>(_ url: URL) throws -> T? {
        let jsonString: String = try String(contentsOf: url, encoding: .utf8)
        guard let dataJson = jsonString.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(T.self, from: dataJson)
    }

    static func unzip(sourceURL: URL, to destinationURL: URL, priority: TaskPriority?) async throws {
        try await Task.detached(priority: priority) {
            try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
        }.value
    }
}
