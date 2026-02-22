//
//  ProjectConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/02/22.
//

import CanvasView
import UIKit

@MainActor
public struct ProjectConfiguration {
    /// File extension used when saving a file
    public let fileSuffix: String

    public let undoCount: Int

    public let canvasConfiguration: CanvasConfiguration

    public init(
        fileSuffix: String = "",
        undoCount: Int = 12,
        canvasConfiguration: CanvasConfiguration
    ) {
        self.fileSuffix = Self.sanitizedFileExtension(fileSuffix)
        self.undoCount = undoCount
        self.canvasConfiguration = canvasConfiguration
    }

    /// Returns a sanitized file extension (without a leading dot)
    static func sanitizedFileExtension(_ input: String?) -> String {
        guard
            var ext = input?.trimmingCharacters(in: .whitespacesAndNewlines),
            !ext.isEmpty
        else { return "" }

        // Allow ".ext" style input
        if ext.hasPrefix(".") { ext.removeFirst() }

        ext = ext.lowercased()

        // Reject invalid characters
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        if ext.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return ""
        }

        // Reject unreasonable length
        guard (1...16).contains(ext.count) else {
            return ""
        }

        // Explicitly disallow common image formats
        if [
            "png",
            "jpg",
            "jpeg",
            "bmp"
        ].contains(ext) {
            return ""
        }

        return ext
    }
}
